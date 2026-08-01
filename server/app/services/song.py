"""학습자료 요약 → 알람용 노래(가사+음원) 생성.

두 단계로 나뉜다:
1) Gemini(google.generativeai, 이미 /summarize에서 쓰는 것과 동일한 API 키)로
   학습 요약을 짧고 외우기 좋은 노래 가사로 변환.
2) Vertex AI의 Lyria 3(Interactions API)로 그 가사를 실제로 "부르는" 곡을 생성.

주의:
- Lyria는 Gemini Developer API 키(GEMINI_API_KEY)가 아니라 Vertex AI를 통해서만
  쓸 수 있고, Vertex AI는 결제(빌링)가 연결된 GCP 프로젝트 + 서비스 계정이 필요하다.
  google-auth의 google.auth.default()가 GOOGLE_APPLICATION_CREDENTIALS 환경변수
  (서비스 계정 JSON 키 파일 경로)를 자동으로 읽어서 access token을 발급해준다.
- lyria-3-pro-preview / lyria-3-clip-preview는 프리뷰 모델이라, GCP 프로젝트에
  Vertex AI API가 활성화돼 있어야 하고 접근 권한이 없으면 403/404가 날 수 있다.
"""

import base64
import os

import google.auth
import google.generativeai as genai
import httpx
from google.auth.transport.requests import Request as GoogleAuthRequest
from google.oauth2 import service_account

from app.core.errors import AppError

GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash-lite")
GCP_PROJECT_ID = os.getenv("GCP_PROJECT_ID")
LYRIA_MODEL = os.getenv("LYRIA_MODEL", "lyria-3-pro-preview")
_VERTEX_SCOPES = ["https://www.googleapis.com/auth/cloud-platform"]

_LYRICS_PROMPT = """
너는 학습 내용을 짧고 외우기 쉬운 노래 가사로 바꿔주는 작사가야.
아래 학습 요약을 바탕으로, 아침 기상 알람으로 틀 노래의 가사를 한국어로 써줘.

조건:
- 벌스(verse) 1개 + 코러스(chorus) 1개, 총 6~10줄 정도의 짧은 길이
- 리듬감 있게 라임을 맞추고, 밝고 신나는 기상 알람 분위기
- 학습 요약의 핵심 키워드/개념이 가사에 자연스럽게 들어가야 함 (암기 도움용)
- 가사 텍스트만 출력, 설명이나 따옴표 없이

과목: {subject}
학습 요약: {summary}
핵심 포인트: {key_points}
"""


def _build_lyrics_prompt(subject: str, summary: str, key_points: list[str]) -> str:
    return _LYRICS_PROMPT.format(
        subject=subject,
        summary=summary,
        key_points=", ".join(key_points) if key_points else "(없음)",
    )


async def generate_lyrics(subject: str, summary: str, key_points: list[str]) -> str:
    """Gemini로 학습 요약 → 노래 가사 변환."""
    import asyncio

    model = genai.GenerativeModel(GEMINI_MODEL)
    prompt = _build_lyrics_prompt(subject, summary, key_points)
    try:
        response = await asyncio.to_thread(model.generate_content, prompt)
        lyrics = (response.text or "").strip()
        if not lyrics:
            raise AppError(status_code=502, error_code="LYRICS_EMPTY", message="가사 생성 결과가 비어있습니다.")
        return lyrics
    except AppError:
        raise
    except Exception as e:
        raise AppError(status_code=502, error_code="LYRICS_FAILED", message=f"가사 생성 실패: {e}") from e


def _get_vertex_access_token() -> str:
    """Vertex AI access token 발급.

    우선순위:
    1) GOOGLE_APPLICATION_CREDENTIALS가 설정돼 있으면 그 서비스 계정 JSON 키 사용
       (조직 정책으로 서비스 계정 키 발급이 막혀 있으면 이 값은 비워두면 됨)
    2) 없으면 google.auth.default()로 로컬 gcloud 로그인 자격증명(ADC) 사용
       — 터미널에서 아래 명령 한 번 실행해두면 이 방식이 자동으로 동작함:
       gcloud auth application-default login --scopes=https://www.googleapis.com/auth/cloud-platform
    """
    cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    if cred_path:
        credentials = service_account.Credentials.from_service_account_file(cred_path, scopes=_VERTEX_SCOPES)
    else:
        try:
            credentials, _ = google.auth.default(scopes=_VERTEX_SCOPES)
        except google.auth.exceptions.DefaultCredentialsError as e:
            raise AppError(
                status_code=500,
                error_code="GCP_CREDENTIALS_MISSING",
                message=(
                    "GCP 인증 정보를 찾을 수 없습니다. 터미널에서 "
                    "'gcloud auth application-default login --scopes=https://www.googleapis.com/auth/cloud-platform' "
                    f"을 실행해주세요. ({e})"
                ),
            ) from e

    credentials.refresh(GoogleAuthRequest())
    return credentials.token


async def generate_song_audio(lyrics: str, mood: str | None = None) -> tuple[bytes, str]:
    """Lyria 3(Interactions API)로 가사를 실제 노래(음원)로 생성. (audio_bytes, mime_type) 반환."""
    if not GCP_PROJECT_ID:
        raise AppError(status_code=500, error_code="GCP_PROJECT_MISSING", message="GCP_PROJECT_ID가 설정되지 않았습니다.")

    style = mood or "밝고 신나는 아침 기상 알람용 K-pop 스타일, 경쾌한 비트, 여성 보컬"
    text_prompt = (
        f"Style: {style}. "
        f"Sing these Korean lyrics as the song (follow them closely, don't change the words):\n{lyrics}"
    )

    token = _get_vertex_access_token()
    url = f"https://aiplatform.googleapis.com/v1beta1/projects/{GCP_PROJECT_ID}/locations/global/interactions"
    body = {
        "model": LYRIA_MODEL,
        "input": [{"type": "text", "text": text_prompt}],
    }

    async with httpx.AsyncClient(timeout=60.0) as client:
        try:
            resp = await client.post(
                url,
                headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json; charset=utf-8"},
                json=body,
            )
        except httpx.HTTPError as e:
            raise AppError(status_code=502, error_code="LYRIA_REQUEST_FAILED", message=f"Lyria 요청 실패: {e}") from e

    if resp.status_code != 200:
        raise AppError(
            status_code=502,
            error_code="LYRIA_API_ERROR",
            message=f"Lyria API 오류 ({resp.status_code}): {resp.text[:500]}",
        )

    data = resp.json()
    audio_output = next((o for o in data.get("outputs", []) if o.get("type") == "audio"), None)
    if audio_output is None or "data" not in audio_output:
        raise AppError(status_code=502, error_code="LYRIA_NO_AUDIO", message="Lyria 응답에 오디오 데이터가 없습니다.")

    audio_bytes = base64.b64decode(audio_output["data"])
    mime_type = audio_output.get("mime_type", "audio/mpeg")
    return audio_bytes, mime_type
