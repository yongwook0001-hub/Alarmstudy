# alarmstudy-server/main.py
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import google.generativeai as genai
import os
from dotenv import load_dotenv
import json

from app.api.auth import router as auth_router
from app.api.materials import router as materials_router
from app.api.sets import router as sets_router
from app.core.errors import AppError

# .env 파일에서 환경 변수(API 키) 로드
load_dotenv()

# Gemini API 설정
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
genai.configure(api_key=GEMINI_API_KEY)

app = FastAPI()


@app.exception_handler(AppError)
async def app_error_handler(request: Request, exc: AppError) -> JSONResponse:
    return JSONResponse(status_code=exc.status_code, content={"error_code": exc.error_code, "message": exc.message})


app.include_router(auth_router, prefix="/api")
app.include_router(sets_router, prefix="/api")
app.include_router(materials_router, prefix="/api")

# 요청 데이터 구조 정의
class SummarizeRequest(BaseModel):
    text: str
    subject: str

# 응답 데이터 구조 정의
class SummarizeResponse(BaseModel):
    title: str
    summary: str
    keyPoints: list[str]
    quizCount: int

@app.get("/")
def read_root():
    return {"status": "AlarmStudy AI Server is running"}

@app.post("/summarize", response_model=SummarizeResponse)
async def summarize_material(request: SummarizeRequest):
    try:
        # 1. 모델 설정 (Gemini 1.5 Flash)
        model = genai.GenerativeModel('gemini-1.5-flash')
        
        # 2. 프롬프트 생성 (Flutter의 ai_service.dart에서 가져온 로직)
        prompt = f"""
        다음 학습 자료를 분석해서 아래 JSON 형식으로만 응답해. JSON 외 다른 텍스트는 절대 쓰지 마.

        학습 자료:
        {request.text}

        과목: {request.subject}

        응답 형식:
        {{
          "title": "학습 자료 제목 (한 줄)",
          "summary": "3~4문장 요약",
          "keyPoints": ["핵심 포인트1", "핵심 포인트2", "핵심 포인트3", "핵심 포인트4"],
          "quizCount": 5
        }}
        """

        # 3. AI 응답 생성
        response = model.generate_content(prompt)
        raw_text = response.text
        
        # 4. JSON 파싱 (마크다운 블록 ```json 제거)
        cleaned_json = raw_text.replace('```json', '').replace('```', '').strip()
        result = json.loads(cleaned_json)
        
        # TODO: 여기에 DB 저장 로직(PostgreSQL 등)을 추가할 예정입니다.
        
        return result

    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)