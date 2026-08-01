import io
import logging
from typing import Protocol

import pdfplumber
from google import genai
from starlette.concurrency import run_in_threadpool

from app.core.config import get_settings
from app.db.session import AsyncSessionLocal
from app.models import StudyMaterial
from app.services import s3

logger = logging.getLogger(__name__)


class SummaryGenerationError(Exception):
    pass


class SummaryGenerator(Protocol):
    async def generate(self, text: str) -> str: ...


class GeminiSummaryGenerator:
    """google-genai로 요약을 생성한다. app/services/oauth.py의 provider verifier와
    동일한 패턴 — Protocol을 만족하는 얇은 래퍼라 테스트에서 통째로 교체(mock) 가능하다."""

    _MAX_EXCERPT_CHARS = 20_000

    def __init__(self, api_key: str, model_name: str = "gemini-1.5-flash") -> None:
        self._api_key = api_key
        self._model_name = model_name

    async def generate(self, text: str) -> str:
        client = genai.Client(api_key=self._api_key)
        excerpt = text[: self._MAX_EXCERPT_CHARS]
        prompt = (
            "다음 학습 자료를 3~4문장으로 한국어로 요약해줘. 요약문만 출력하고 "
            f"다른 말은 하지 마.\n\n{excerpt}"
        )
        try:
            response = await client.aio.models.generate_content(model=self._model_name, contents=prompt)
            return (response.text or "").strip()
        except Exception as exc:
            raise SummaryGenerationError(str(exc)) from exc


def _default_summary_generator() -> SummaryGenerator:
    return GeminiSummaryGenerator(api_key=get_settings().gemini_api_key)


async def _extract_text(pdf_bytes: bytes) -> tuple[str, int]:
    def _parse() -> tuple[str, int]:
        with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
            pages_text = [page.extract_text() or "" for page in pdf.pages]
            return "\n".join(pages_text), len(pdf.pages)

    return await run_in_threadpool(_parse)


async def parse_material(material_id: int, summary_generator: SummaryGenerator | None = None) -> None:
    """BackgroundTasks 진입점: S3 다운로드→pdfplumber 추출→Gemini 요약→'ready'.

    어느 단계든 실패하면 'parse_failed'로 전환한다. 요청-응답 사이클이 끝난 뒤
    실행되므로 요청에 쓰인 세션을 재사용하지 않고 이 함수 안에서 새 세션을 연다.
    """
    generator = summary_generator or _default_summary_generator()

    async with AsyncSessionLocal() as db:
        material = await db.get(StudyMaterial, material_id)
        if material is None:
            logger.warning("parse_material: material_id=%s 없음 (그 사이 삭제된 것으로 추정)", material_id)
            return

        try:
            pdf_bytes = await s3.download_object(material.s3_key)
            extracted_text, page_count = await _extract_text(pdf_bytes)
            summary = await generator.generate(extracted_text)
        except Exception:
            logger.exception("자료 파싱 실패 (material_id=%s)", material_id)
            material.upload_status = "parse_failed"
            await db.commit()
            return

        material.extracted_text = extracted_text
        material.page_count = page_count
        material.summary = summary
        material.upload_status = "ready"
        await db.commit()
