import uuid
from datetime import datetime, timezone

from sqlalchemy import select

from app.db.session import AsyncSessionLocal
from app.models import AlarmSession, MaterialSet, QuestionAttempt, StudyMaterial, User, WeakAreaAnalysis
from app.services.analysis import AnalysisCommentError, update_weak_area_analysis

# ---- seed helpers ------------------------------------------------------------


async def _seed_user() -> int:
    async with AsyncSessionLocal() as db:
        user = User(provider="google", provider_user_id=f"analysis-{uuid.uuid4()}", nickname="분석테스터")
        db.add(user)
        await db.commit()
        await db.refresh(user)
        return user.id


async def _seed_set(user_id: int) -> int:
    async with AsyncSessionLocal() as db:
        material_set = MaterialSet(user_id=user_id, title="분석 세트")
        db.add(material_set)
        await db.commit()
        await db.refresh(material_set)
        return material_set.id


async def _seed_material(set_id: int) -> int:
    async with AsyncSessionLocal() as db:
        material = StudyMaterial(
            set_id=set_id,
            is_main=True,
            file_name="m.pdf",
            s3_key=f"analysis-test/{uuid.uuid4()}.pdf",
            file_size_bytes=1,
            upload_status="ready",
            extracted_text="본문",
        )
        db.add(material)
        await db.commit()
        await db.refresh(material)
        return material.id


async def _seed_alarm_session(user_id: int) -> int:
    async with AsyncSessionLocal() as db:
        session_row = AlarmSession(user_id=user_id, alarm_id=None, started_at=datetime.now(timezone.utc))
        db.add(session_row)
        await db.commit()
        await db.refresh(session_row)
        return session_row.id


async def _seed_attempt(session_id: int, material_id: int, topic: str, is_correct: bool) -> None:
    async with AsyncSessionLocal() as db:
        db.add(
            QuestionAttempt(
                session_id=session_id,
                material_id=material_id,
                topic=topic,
                is_correct=is_correct,
                source="buffer",
            )
        )
        await db.commit()


async def _get_analysis(set_id: int) -> WeakAreaAnalysis | None:
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(WeakAreaAnalysis).where(WeakAreaAnalysis.set_id == set_id))
        return result.scalar_one_or_none()


class _FixedCommentGenerator:
    def __init__(self, comment: str) -> None:
        self._comment = comment
        self.calls = 0

    async def generate(self, weak_topics: list[dict]) -> str:
        self.calls += 1
        return self._comment


class _FailingCommentGenerator:
    async def generate(self, weak_topics: list[dict]) -> str:
        raise AnalysisCommentError("모의 AI 실패")


class _NeverCalledCommentGenerator:
    async def generate(self, weak_topics: list[dict]) -> str:
        raise AssertionError("집계할 attempts가 없으면 AI가 호출되면 안 된다")


# ---- tests ------------------------------------------------------------


async def test_creates_new_analysis_row_with_accuracy_sorted_ascending():
    user_id = await _seed_user()
    set_id = await _seed_set(user_id)
    material_id = await _seed_material(set_id)
    session_id = await _seed_alarm_session(user_id)

    await _seed_attempt(session_id, material_id, "이진트리", True)
    await _seed_attempt(session_id, material_id, "이진트리", False)  # 50%
    await _seed_attempt(session_id, material_id, "그래프", True)  # 100%

    generator = _FixedCommentGenerator("코멘트입니다")
    await update_weak_area_analysis(set_id, comment_generator=generator)

    analysis = await _get_analysis(set_id)
    assert analysis is not None
    assert analysis.comment == "코멘트입니다"
    assert analysis.weak_topics == [
        {"topic": "이진트리", "accuracy": 50},
        {"topic": "그래프", "accuracy": 100},
    ]
    assert generator.calls == 1


async def test_second_run_updates_existing_row_and_overwrites_comment_on_success():
    user_id = await _seed_user()
    set_id = await _seed_set(user_id)
    material_id = await _seed_material(set_id)
    session_id = await _seed_alarm_session(user_id)

    await _seed_attempt(session_id, material_id, "순회", False)
    await update_weak_area_analysis(set_id, comment_generator=_FixedCommentGenerator("첫 코멘트"))

    await _seed_attempt(session_id, material_id, "순회", True)  # 누적 2개 중 1개 정답 → 50%
    await update_weak_area_analysis(set_id, comment_generator=_FixedCommentGenerator("두번째 코멘트"))

    analysis = await _get_analysis(set_id)
    assert analysis.comment == "두번째 코멘트"
    assert analysis.weak_topics == [{"topic": "순회", "accuracy": 50}]


async def test_ai_failure_keeps_previous_comment_but_still_updates_weak_topics():
    user_id = await _seed_user()
    set_id = await _seed_set(user_id)
    material_id = await _seed_material(set_id)
    session_id = await _seed_alarm_session(user_id)

    await _seed_attempt(session_id, material_id, "순회", False)
    await update_weak_area_analysis(set_id, comment_generator=_FixedCommentGenerator("보존되어야 할 코멘트"))

    await _seed_attempt(session_id, material_id, "탐색", True)
    await update_weak_area_analysis(set_id, comment_generator=_FailingCommentGenerator())

    analysis = await _get_analysis(set_id)
    assert analysis.comment == "보존되어야 할 코멘트"  # AI 실패 시 이전 값 유지
    topics = {item["topic"]: item["accuracy"] for item in analysis.weak_topics}
    assert topics == {"순회": 0, "탐색": 100}


async def test_no_attempts_skips_ai_call_and_stores_empty_weak_topics():
    user_id = await _seed_user()
    set_id = await _seed_set(user_id)

    await update_weak_area_analysis(set_id, comment_generator=_NeverCalledCommentGenerator())

    analysis = await _get_analysis(set_id)
    assert analysis is not None
    assert analysis.weak_topics == []
    assert analysis.comment is None


async def test_missing_set_is_a_noop():
    await update_weak_area_analysis(999_999, comment_generator=_NeverCalledCommentGenerator())

    assert await _get_analysis(999_999) is None
