import json
import uuid

from sqlalchemy import delete, func, select

from app.core.constants import BUFFER_TARGET_PER_SET, GENERATION_BATCH_SIZE, GENERATION_MAX_RETRY, TOKEN_LIMIT_PER_SET
from app.db.session import AsyncSessionLocal
from app.models import GenerationJob, MaterialSet, Question, StudyMaterial, User
from app.services.question_generator import QuestionGenerationError, RawGenerationResponse
from app.workers import generation_worker


# ---- seed helpers ------------------------------------------------------------


async def _seed_user() -> int:
    async with AsyncSessionLocal() as db:
        user = User(provider="google", provider_user_id=f"worker-{uuid.uuid4()}", nickname="워커테스트")
        db.add(user)
        await db.commit()
        await db.refresh(user)
        return user.id


async def _seed_set(user_id: int, tokens_used: int = 0) -> int:
    async with AsyncSessionLocal() as db:
        material_set = MaterialSet(user_id=user_id, title="워커 세트", tokens_used=tokens_used)
        db.add(material_set)
        await db.commit()
        await db.refresh(material_set)
        return material_set.id


async def _seed_material(set_id: int, is_main: bool = True) -> int:
    async with AsyncSessionLocal() as db:
        material = StudyMaterial(
            set_id=set_id,
            is_main=is_main,
            file_name="m.pdf",
            s3_key=f"worker-test/{uuid.uuid4()}.pdf",
            file_size_bytes=1,
            upload_status="ready",
            extracted_text="본문 텍스트",
        )
        db.add(material)
        await db.commit()
        await db.refresh(material)
        return material.id


async def _seed_job(set_id: int, status: str = "pending", retry_count: int = 0) -> int:
    async with AsyncSessionLocal() as db:
        job = GenerationJob(set_id=set_id, status=status, trigger_type="alarm_activated", retry_count=retry_count)
        db.add(job)
        await db.commit()
        await db.refresh(job)
        return job.id


async def _seed_questions(material_id: int, count: int) -> None:
    async with AsyncSessionLocal() as db:
        for i in range(count):
            db.add(
                Question(
                    material_id=material_id,
                    content=f"기존 문제 {i}",
                    choices=["a", "b", "c", "d"],
                    correct_answer=0,
                    topic="topic",
                )
            )
        await db.commit()


async def _get_job(job_id: int) -> GenerationJob | None:
    async with AsyncSessionLocal() as db:
        return await db.get(GenerationJob, job_id)


async def _get_set(set_id: int) -> MaterialSet | None:
    async with AsyncSessionLocal() as db:
        return await db.get(MaterialSet, set_id)


async def _count_questions(material_id: int) -> int:
    async with AsyncSessionLocal() as db:
        return await db.scalar(select(func.count(Question.id)).where(Question.material_id == material_id))


def _questions_json(n: int) -> str:
    return json.dumps(
        [
            {"content": f"문제 {i}", "choices": ["a", "b", "c", "d"], "correct_answer": 0, "topic": "topic"}
            for i in range(n)
        ]
    )


class _FixedClient:
    def __init__(self, text: str, tokens_used: int) -> None:
        self._text = text
        self._tokens_used = tokens_used
        self.calls = 0

    async def generate(self, prompt: str) -> RawGenerationResponse:
        self.calls += 1
        return RawGenerationResponse(text=self._text, tokens_used=self._tokens_used)


class _AlwaysFailsClient:
    async def generate(self, prompt: str) -> RawGenerationResponse:
        raise QuestionGenerationError("모의 생성 실패")


class _NeverCalledClient:
    async def generate(self, prompt: str) -> RawGenerationResponse:
        raise AssertionError("목표가 이미 충족된 상태라 호출되면 안 된다")


def _patch_client(monkeypatch, client) -> None:
    monkeypatch.setattr("app.services.question_generator._default_generation_client", lambda: client)


# ---- tests ------------------------------------------------------------


async def test_process_one_job_picks_up_pending_saves_questions_and_deletes_job(monkeypatch):
    user_id = await _seed_user()
    set_id = await _seed_set(user_id)
    material_id = await _seed_material(set_id)
    # 목표가 정확히 한 배치(GENERATION_BATCH_SIZE)만큼만 남도록 기존 버퍼를 채워둔다 —
    # 배치 분할·가중치 산술 자체는 test_question_generator.py가 이미 별도로 검증한다.
    await _seed_questions(material_id, BUFFER_TARGET_PER_SET - GENERATION_BATCH_SIZE)
    job_id = await _seed_job(set_id)

    client = _FixedClient(_questions_json(GENERATION_BATCH_SIZE), 500)
    _patch_client(monkeypatch, client)

    handled = await generation_worker.process_one_job()

    assert handled is True
    assert client.calls == 1
    assert await _get_job(job_id) is None  # completed → row 삭제
    assert await _count_questions(material_id) == BUFFER_TARGET_PER_SET

    material_set = await _get_set(set_id)
    assert material_set.tokens_used == 500


async def test_target_already_met_completes_immediately_without_calling_client(monkeypatch):
    user_id = await _seed_user()
    set_id = await _seed_set(user_id)
    material_id = await _seed_material(set_id)
    await _seed_questions(material_id, BUFFER_TARGET_PER_SET)  # 이미 목표 충족
    job_id = await _seed_job(set_id)

    _patch_client(monkeypatch, _NeverCalledClient())

    handled = await generation_worker.process_one_job()

    assert handled is True
    assert await _get_job(job_id) is None
    assert await _count_questions(material_id) == BUFFER_TARGET_PER_SET  # 늘지 않았다


async def test_generation_failure_increments_retry_and_fails_on_max_attempt(monkeypatch):
    user_id = await _seed_user()
    set_id = await _seed_set(user_id)
    await _seed_material(set_id)
    job_id = await _seed_job(set_id)

    _patch_client(monkeypatch, _AlwaysFailsClient())

    for attempt in range(1, GENERATION_MAX_RETRY + 1):
        handled = await generation_worker.process_one_job()
        assert handled is True

        job = await _get_job(job_id)
        assert job is not None
        assert job.retry_count == attempt

        if attempt < GENERATION_MAX_RETRY:
            assert job.status == "pending"
        else:
            assert job.status == "failed"
            assert job.error_message


async def test_token_limit_reached_mid_run_still_completes_the_job(monkeypatch):
    user_id = await _seed_user()
    set_id = await _seed_set(user_id, tokens_used=TOKEN_LIMIT_PER_SET - 50)
    material_id = await _seed_material(set_id)
    job_id = await _seed_job(set_id)

    client = _FixedClient(_questions_json(GENERATION_BATCH_SIZE), 100)  # 이 한 번으로 한도를 넘긴다
    _patch_client(monkeypatch, client)

    handled = await generation_worker.process_one_job()

    assert handled is True
    assert client.calls == 1  # 한도 초과 직후 더 호출하지 않는다
    assert await _get_job(job_id) is None  # 에러가 아니라 completed로 마감된다
    assert await _count_questions(material_id) == GENERATION_BATCH_SIZE

    material_set = await _get_set(set_id)
    assert material_set.tokens_used == TOKEN_LIMIT_PER_SET + 50


async def test_recover_stale_processing_jobs_resets_to_pending():
    user_id = await _seed_user()
    set_id = await _seed_set(user_id)
    job_id = await _seed_job(set_id, status="processing")

    async with AsyncSessionLocal() as db:
        await generation_worker.recover_stale_processing_jobs(db)
        await db.commit()

    job = await _get_job(job_id)
    assert job.status == "pending"

    # 다른 테스트의 전역 폴링 가정(예: "pending 없음")에 영향을 주지 않도록 직접 정리한다.
    async with AsyncSessionLocal() as db:
        await db.execute(delete(GenerationJob).where(GenerationJob.id == job_id))
        await db.commit()
