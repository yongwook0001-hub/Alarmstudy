# server/app/main.py
#
# 팀원별로 따로 구현되어 있던 파서(front: Gemini 직접 호출 + PDF/재시도/퀴즈 로직,
# back/docker: FastAPI+Postgres 서버 골격)를 하나로 합친 버전.
# 실제 Gemini 호출과 응답 파싱은 전부 서버(여기)에서 담당하고,
# Flutter 클라이언트는 이 서버에 HTTP 요청만 보낸다.
#
# 인증(구글/카카오 로그인 + JWT)은 팀원이 만든 app/api/auth.py 라우터를 그대로 사용.
# users/refresh_tokens 포함 전체 DB 스키마(alarms, material_sets, questions 등)는
# 팀원이 app/models/, app/db/, alembic/로 이미 구성해뒀다.
import asyncio
import json
import os

from dotenv import load_dotenv
from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import JSONResponse
from pydantic import BaseModel

import google.generativeai as genai

from app.api.auth import router as auth_router
from app.api.song import router as song_router
from app.core.errors import AppError

# .env 파일에서 환경 변수(API 키) 로드
load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
genai.configure(api_key=GEMINI_API_KEY)

# front 브랜치에서 쓰던 모델명을 그대로 유지 (gemini-1.5-flash보다 최신/무료 티어에 적합)
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash-lite")

app = FastAPI(title="AlarmStudy AI Server")


@app.exception_handler(AppError)
async def app_error_handler(request: Request, exc: AppError) -> JSONResponse:
    return JSONResponse(status_code=exc.status_code, content={"error_code": exc.error_code, "message": exc.message})


app.include_router(auth_router, prefix="/api")
app.include_router(song_router, prefix="/api")


# ── 요청/응답 스키마 ─────────────────────────────────────────────
class SummarizeRequest(BaseModel):
    text: str
    subject: str


class QuizQuestionOut(BaseModel):
    question: str
    options: list[str]
    correctIndex: int
    topic: str


class SummarizeResponse(BaseModel):
    title: str
    summary: str
    keyPoints: list[str]
    quizCount: int
    quiz: list[QuizQuestionOut]


# ── 공통: 요약+퀴즈 3문제를 한 번에 요청하는 프롬프트 ──────────────
# front의 _responseFormat을 그대로 포팅.
# "t" 필드: 문제가 속한 세부 주제 - 나중에 주제별 정답률 계산에 사용됨.
_RESPONSE_FORMAT = """
JSON만 반환. 다른 텍스트 금지.
{
  "title": "제목",
  "summary": "2문장 요약",
  "keyPoints": ["포인트1","포인트2","포인트3"],
  "quiz": [
    {"q":"문제","o":["보기1","보기2","보기3","보기4"],"a":0,"t":"세부주제명"}
  ]
}
quiz는 정확히 3개, a는 0~3 정수, t는 문제가 다루는 세부 개념(예: "이진트리","그래프","순회" 등 2~4글자).
"""


def _build_model() -> genai.GenerativeModel:
    return genai.GenerativeModel(GEMINI_MODEL)


def _parse_response(raw_text: str, subject: str) -> dict:
    """Gemini 응답(raw JSON 문자열)을 SummarizeResponse 형태의 dict로 변환.
    front의 AiService._parse()를 그대로 포팅."""
    cleaned = (raw_text or "").replace("```json", "").replace("```", "").strip()
    data = json.loads(cleaned)

    quiz_out = []
    for q in data.get("quiz", []):
        topic = q.get("t")
        topic = topic.strip() if isinstance(topic, str) and topic.strip() else subject
        quiz_out.append(
            {
                "question": q["q"],
                "options": list(q["o"]),
                "correctIndex": q["a"],
                "topic": topic,
            }
        )

    return {
        "title": data["title"],
        "summary": data["summary"],
        "keyPoints": list(data.get("keyPoints", [])),
        "quizCount": len(quiz_out),
        "quiz": quiz_out,
    }


def _to_readable_error(e: Exception) -> HTTPException:
    """front의 AiService._toReadableException()을 그대로 포팅.
    Gemini 예외 메시지에 담긴 HTTP 상태코드를 사용자에게 읽기 쉬운 메시지로 변환.

    참고: 인증 라우터(app/api/auth.py)는 AppError({error_code, message}) 형식을 쓰고
    여기(/summarize)는 HTTPException({detail})을 쓴다 — 두 응답 형식이 다른 건
    의도적으로 남겨둔 것이며, 나중에 하나로 통일하면 더 좋다."""
    msg = str(e)
    lower = msg.lower()
    print(f"[AiService] Gemini error: {msg}")

    if "503" in msg or "unavailable" in lower:
        return HTTPException(status_code=503, detail=f"서버 과부하 (503). 잠시 후 다시 시도해주세요.\n원문: {msg}")
    if "429" in msg or "quota" in lower or "resource exhausted" in lower:
        return HTTPException(status_code=429, detail=f"API 할당량 초과 (429). 잠시 후 다시 시도해주세요.\n원문: {msg}")
    if "400" in msg:
        return HTTPException(status_code=400, detail=f"잘못된 요청 (400). 파일이 손상됐거나 지원되지 않는 형식일 수 있습니다.\n원문: {msg}")
    if "403" in msg:
        return HTTPException(status_code=403, detail=f"API 키 권한 오류 (403).\n원문: {msg}")
    return HTTPException(status_code=502, detail=f"Gemini 오류: {msg}")


@app.get("/")
def read_root():
    return {"status": "AlarmStudy AI Server is running"}


# ── 텍스트 입력 → 요약+퀴즈 (1회 호출) ────────────────────────────
@app.post("/summarize", response_model=SummarizeResponse)
async def summarize_material(request: SummarizeRequest):
    trimmed = request.text[:1500]
    prompt = f"학습자료:\n{trimmed}\n\n{_RESPONSE_FORMAT}"

    try:
        response = await asyncio.to_thread(_build_model().generate_content, prompt)
        return _parse_response(response.text or "", request.subject)
    except (json.JSONDecodeError, KeyError) as e:
        raise HTTPException(status_code=502, detail=f"AI 응답 파싱 실패: {e}")
    except Exception as e:
        raise _to_readable_error(e)


# ── PDF 입력 → 요약+퀴즈 (503 시 1회 재시도) ──────────────────────
@app.post("/summarize/pdf", response_model=SummarizeResponse)
async def summarize_pdf(subject: str = Form(...), file: UploadFile = File(...)):
    pdf_bytes = await file.read()
    size_kb = len(pdf_bytes) / 1024
    print(f"[AiService] PDF 수신 — {size_kb:.1f}KB")

    prompt = f"이 PDF를 분석해.\n{_RESPONSE_FORMAT}"
    last_error: Exception | None = None

    for attempt in (1, 2):
        try:
            response = await asyncio.to_thread(
                _build_model().generate_content,
                [{"mime_type": "application/pdf", "data": pdf_bytes}, prompt],
            )
            print(f"[AiService] PDF 응답 수신 — {len(response.text or '')}자")
            return _parse_response(response.text or "", subject)
        except (json.JSONDecodeError, KeyError) as e:
            raise HTTPException(status_code=502, detail=f"AI 응답 파싱 실패: {e}")
        except Exception as e:
            last_error = e
            msg = str(e).lower()
            print(f"[AiService] 시도 {attempt} 실패: {e}")
            if attempt == 1 and ("503" in msg or "unavailable" in msg):
                print("[AiService] 503 감지 — 3초 후 재시도")
                await asyncio.sleep(3)
                continue
            raise _to_readable_error(e)

    # 두 번 모두 503으로 실패한 경우
    raise HTTPException(status_code=503, detail="서버가 일시적으로 응답하지 않습니다 (503). 잠시 후 다시 시도해주세요.") from last_error


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
