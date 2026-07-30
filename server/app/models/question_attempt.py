from datetime import datetime

from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Integer, SmallInteger, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class QuestionAttempt(Base):
    """스냅샷 전용. questions FK를 두지 않는다 — 정답 즉시삭제 정책과 충돌하므로 (의도적 설계)."""

    __tablename__ = "question_attempts"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    session_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("alarm_sessions.id", ondelete="CASCADE"), nullable=False
    )
    material_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("study_materials.id", ondelete="SET NULL"), nullable=True
    )
    topic: Mapped[str] = mapped_column(String(50), nullable=False)
    is_correct: Mapped[bool] = mapped_column(Boolean, nullable=False)
    selected_answer: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    time_taken_seconds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    source: Mapped[str] = mapped_column(String(10), nullable=False, server_default="buffer")
    attempted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
