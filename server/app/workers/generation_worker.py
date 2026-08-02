import asyncio
import logging
from datetime import datetime, timezone

from sqlalchemy import delete, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.constants import BUFFER_TARGET_PER_SET, GENERATION_MAX_RETRY, WORKER_POLL_INTERVAL_SECONDS
from app.db.session import AsyncSessionLocal
from app.models import GenerationJob, MaterialSet, Question, StudyMaterial
from app.services.question_generator import generate_questions_for_set

logger = logging.getLogger(__name__)


async def recover_stale_processing_jobs(db: AsyncSession) -> None:
    """기동 시 호출: 'processing' job은 이전 프로세스가 남긴 것일 수밖에 없다 (이
    프로세스는 방금 떴으니 실제로 진행 중인 작업일 리 없다) — 전부 pending으로 되돌려
    다음 폴링에서 재시도되게 한다. 커밋은 호출부 책임."""
    await db.execute(update(GenerationJob).where(GenerationJob.status == "processing").values(status="pending"))


async def _claim_next_pending_job() -> tuple[int, int] | None:
    """pending job 하나를 SELECT ... FOR UPDATE SKIP LOCKED로 집어 processing 전환한다.
    느린 Gemini 호출 전에 즉시 커밋해 행 잠금 보유 시간을 짧게 유지한다.

    반환: (job_id, set_id). 집을 job이 없으면 None.
    """
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(GenerationJob)
            .where(GenerationJob.status == "pending")
            .order_by(GenerationJob.created_at)
            .limit(1)
            .with_for_update(skip_locked=True)
        )
        job = result.scalar_one_or_none()
        if job is None:
            return None

        job.status = "processing"
        job.started_at = datetime.now(timezone.utc)
        await db.commit()
        return job.id, job.set_id


async def _mark_job_failure_or_retry(job_id: int, error_message: str) -> None:
    async with AsyncSessionLocal() as db:
        job = await db.get(GenerationJob, job_id)
        if job is None:
            return

        job.retry_count += 1
        if job.retry_count >= GENERATION_MAX_RETRY:
            job.status = "failed"
            job.error_message = error_message
            job.finished_at = datetime.now(timezone.utc)
        else:
            job.status = "pending"
        await db.commit()


async def _run_job(job_id: int, set_id: int) -> None:
    """생성 실행 + 마무리를 한 트랜잭션으로 처리한다 — 성공하면 questions 저장·
    tokens_used 갱신·job 삭제가 모두 커밋되고, 도중에 실패하면 아무것도 커밋되지
    않은 채 새 세션에서 retry_count만 갱신한다 (부분 반영 방지)."""
    try:
        async with AsyncSessionLocal() as db:
            material_set = await db.get(MaterialSet, set_id)
            if material_set is None:
                # 세트가 그 사이 삭제됨: CASCADE로 이미 지워졌어야 하지만 방어적으로 정리.
                await db.execute(delete(GenerationJob).where(GenerationJob.id == job_id))
                await db.commit()
                return

            materials = list(
                (await db.execute(select(StudyMaterial).where(StudyMaterial.set_id == set_id))).scalars().all()
            )

            current_count = await db.scalar(
                select(func.count(Question.id))
                .join(StudyMaterial, Question.material_id == StudyMaterial.id)
                .where(StudyMaterial.set_id == set_id)
            )
            target = BUFFER_TARGET_PER_SET - (current_count or 0)

            if target > 0:
                allocations = await generate_questions_for_set(material_set, materials, target)
                for material_id, questions in allocations.items():
                    for q in questions:
                        db.add(
                            Question(
                                material_id=material_id,
                                content=q.content,
                                choices=q.choices,
                                correct_answer=q.correct_answer,
                                explanation=q.explanation,
                                topic=q.topic,
                            )
                        )

            # target <= 0(이미 충족)이면 위 블록을 건너뛰고 바로 여기로 와 completed 처리된다.
            await db.execute(delete(GenerationJob).where(GenerationJob.id == job_id))
            await db.commit()
    except Exception as exc:
        logger.exception("문제 생성 작업 실패 (job_id=%s, set_id=%s)", job_id, set_id)
        await _mark_job_failure_or_retry(job_id, str(exc))


async def process_one_job() -> bool:
    """대기 중인 job을 하나 집어 끝까지 처리한다. 처리할 job이 있었으면 True."""
    claimed = await _claim_next_pending_job()
    if claimed is None:
        return False

    job_id, set_id = claimed
    await _run_job(job_id, set_id)
    return True


async def run_poll_loop() -> None:
    """WORKER_POLL_INTERVAL_SECONDS 주기로 폴링하되, 매 틱마다 쌓인 pending job을
    전부 소진한 뒤 잠든다 — 여러 세트가 동시에 트리거돼도 다음 틱까지 밀리지 않는다.
    """
    while True:
        while await process_one_job():
            pass
        await asyncio.sleep(WORKER_POLL_INTERVAL_SECONDS)
