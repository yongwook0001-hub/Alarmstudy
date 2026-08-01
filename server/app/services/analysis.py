import logging
import os
from datetime import datetime, timezone
from typing import Protocol

from google import genai
from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.db.session import AsyncSessionLocal
from app.models import MaterialSet, QuestionAttempt, StudyMaterial, WeakAreaAnalysis

logger = logging.getLogger(__name__)

_GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash-lite")


class AnalysisCommentError(Exception):
    pass


class AnalysisCommentGenerator(Protocol):
    async def generate(self, weak_topics: list[dict]) -> str: ...


class GeminiAnalysisCommentGenerator:
    """google-genai로 취약분석 코멘트를 생성한다. app/services/parsing.py의 SummaryGenerator와
    동일한 패턴 — Protocol을 만족하는 얇은 래퍼라 테스트에서 통째로 교체(mock) 가능하다."""

    def __init__(self, api_key: str, model_name: str = _GEMINI_MODEL) -> None:
        self._api_key = api_key
        self._model_name = model_name

    async def generate(self, weak_topics: list[dict]) -> str:
        client = genai.Client(api_key=self._api_key)
        topics_text = "\n".join(f"- {item['topic']}: 정답률 {item['accuracy']}%" for item in weak_topics)
        prompt = (
            "다음은 한 학습자의 주제별 정답률 통계다. 가장 취약한 주제 위주로 "
            "2~3문장의 한국어 코멘트를 작성해줘. 코멘트만 출력하고 다른 말은 하지 마.\n\n"
            f"{topics_text}"
        )
        try:
            response = await client.aio.models.generate_content(model=self._model_name, contents=prompt)
            return (response.text or "").strip()
        except Exception as exc:
            raise AnalysisCommentError(str(exc)) from exc


def _default_comment_generator() -> AnalysisCommentGenerator:
    return GeminiAnalysisCommentGenerator(api_key=get_settings().gemini_api_key)


async def _aggregate_weak_topics(db: AsyncSession, set_id: int) -> list[dict]:
    rows = (
        await db.execute(
            select(
                QuestionAttempt.topic,
                func.count(QuestionAttempt.id),
                func.count(QuestionAttempt.id).filter(QuestionAttempt.is_correct.is_(True)),
            )
            .join(StudyMaterial, QuestionAttempt.material_id == StudyMaterial.id)
            .where(StudyMaterial.set_id == set_id)
            .group_by(QuestionAttempt.topic)
        )
    ).all()

    weak_topics = [
        {"topic": topic, "accuracy": round(100 * correct / total)} for topic, total, correct in rows if total
    ]
    # 정답률 오름차순 — 가장 취약한 주제가 앞에 오도록 (필터링 없이 전체 주제를 담는다)
    weak_topics.sort(key=lambda item: item["accuracy"])
    return weak_topics


async def _upsert_weak_area_analysis(
    db: AsyncSession,
    user_id: int,
    set_id: int,
    weak_topics: list[dict],
    comment: str | None,
) -> None:
    stmt = pg_insert(WeakAreaAnalysis).values(
        user_id=user_id,
        set_id=set_id,
        weak_topics=weak_topics,
        comment=comment,
        analyzed_at=datetime.now(timezone.utc),
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=["set_id"],
        set_={
            "weak_topics": stmt.excluded.weak_topics,
            # comment는 새 값이 있을 때만 덮어쓴다 — AI 실패(None) 시 기존 값을 그대로 둔다.
            "comment": func.coalesce(stmt.excluded.comment, WeakAreaAnalysis.comment),
            "analyzed_at": stmt.excluded.analyzed_at,
        },
    )
    await db.execute(stmt)


async def update_weak_area_analysis(set_id: int, comment_generator: AnalysisCommentGenerator | None = None) -> None:
    """BackgroundTasks 진입점: 세션 dismiss 성공 시 호출된다.

    question_attempts를 topic별로 집계(해당 세트 자료 전체, 세션 하나가 아니라 누적 통계)
    → AI 코멘트 생성 → weak_area_analyses upsert. AI 실패 시 weak_topics만 갱신하고
    comment는 이전 값을 유지한다 (에러로 취급하지 않음).
    """
    async with AsyncSessionLocal() as db:
        material_set = await db.get(MaterialSet, set_id)
        if material_set is None:
            logger.warning("update_weak_area_analysis: set_id=%s 없음 (그 사이 삭제된 것으로 추정)", set_id)
            return

        weak_topics = await _aggregate_weak_topics(db, set_id)

        comment: str | None = None
        if weak_topics:
            generator = comment_generator or _default_comment_generator()
            try:
                comment = await generator.generate(weak_topics)
            except AnalysisCommentError:
                logger.exception("취약분석 AI 코멘트 생성 실패 (set_id=%s)", set_id)
                comment = None

        await _upsert_weak_area_analysis(
            db, user_id=material_set.user_id, set_id=set_id, weak_topics=weak_topics, comment=comment
        )
        await db.commit()
