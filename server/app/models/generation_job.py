from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, Index, SmallInteger, String, Text, func, text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class GenerationJob(Base):
    """세트 단위 비동기 문제 생성 작업. wrong_answers와 무관 (재출제는 세션 시작 시 조회 로직)."""

    __tablename__ = "generation_jobs"
    __table_args__ = (
        # 세트당 진행 중(pending/processing) 작업 중복 차단 (부분 UNIQUE)
        Index(
            "uq_generation_jobs_set_id_active",
            "set_id",
            unique=True,
            postgresql_where=text("status IN ('pending', 'processing')"),
        ),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    set_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("material_sets.id", ondelete="CASCADE"), nullable=False
    )
    status: Mapped[str] = mapped_column(String(12), nullable=False, server_default="pending")
    trigger_type: Mapped[str] = mapped_column(String(20), nullable=False)
    retry_count: Mapped[int] = mapped_column(SmallInteger, nullable=False, server_default="0")
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
