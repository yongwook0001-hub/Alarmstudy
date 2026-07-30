from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, Text, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class WeakAreaAnalysis(Base):
    """세트당 최신 1건 갱신. 갱신 트리거: 세션 dismiss 성공 시 BackgroundTasks."""

    __tablename__ = "weak_area_analyses"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    set_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("material_sets.id", ondelete="CASCADE"), nullable=False, unique=True
    )
    weak_topics: Mapped[list | None] = mapped_column(JSONB, nullable=True)
    comment: Mapped[str | None] = mapped_column(Text, nullable=True)
    analyzed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
