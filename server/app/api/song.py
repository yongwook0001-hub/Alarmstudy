"""학습자료 요약 → 알람용 노래(가사+음원) 생성 엔드포인트.

지금은 study_materials 테이블과 연결하지 않고, /summarize처럼 요청 본문으로
요약 텍스트를 직접 받는 stateless 방식으로 구현했다 (아직 요약 결과를 DB에
저장하는 흐름이 없어서 — main.py의 /summarize 참고).
나중에 학습자료가 DB에 저장되면 material_id만 받아서 서버에서 summary를
조회하도록 바꾸면 된다.
"""

import base64

from fastapi import APIRouter
from pydantic import BaseModel

from app.services.song import generate_lyrics, generate_song_audio

router = APIRouter()


class SongRequest(BaseModel):
    subject: str
    summary: str
    key_points: list[str] = []
    mood: str | None = None  # 선택: 곡 스타일 힌트 (예: "잔잔한 로파이", "신나는 K-pop")


class SongResponse(BaseModel):
    lyrics: str
    audio_base64: str
    mime_type: str


@router.post("/songs/generate", response_model=SongResponse)
async def generate_song(request: SongRequest):
    lyrics = await generate_lyrics(request.subject, request.summary, request.key_points)
    audio_bytes, mime_type = await generate_song_audio(lyrics, request.mood)
    return SongResponse(
        lyrics=lyrics,
        audio_base64=base64.b64encode(audio_bytes).decode("ascii"),
        mime_type=mime_type,
    )
