from sqlalchemy import text
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import GenerationJob

# generation_jobs의 부분 UNIQUE(set_id) 대상과 정확히 같은 조건이어야 ON CONFLICT의
# 판정 인덱스로 인식된다 (app/models/generation_job.py의 인덱스 정의와 동일한 조건).
_ACTIVE_JOB_STATUSES_SQL = text("status IN ('pending', 'processing')")


async def insert_job_if_absent(db: AsyncSession, set_id: int, trigger_type: str) -> None:
    """이미 진행 중(pending/processing)인 작업이 있으면 조용히 스킵한다 (설계 확정, 에러 아님).

    알람 API(POST/PATCH)와 세션 API(버퍼 소진 시)가 공통으로 쓰는 job 생성 진입점이다.
    """
    stmt = (
        pg_insert(GenerationJob)
        .values(set_id=set_id, trigger_type=trigger_type)
        .on_conflict_do_nothing(index_elements=["set_id"], index_where=_ACTIVE_JOB_STATUSES_SQL)
    )
    await db.execute(stmt)
