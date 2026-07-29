from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class AlarmSession(Base):
    __tablename__ = "alarm_sessions"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    # 알람 삭제해도 세션 기록은 보존 (SET NULL)
    alarm_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("alarms.id", ondelete="SET NULL"), nullable=True
    )
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    # null=미해제 (별도 status 컬럼 없음)
    dismissed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    dismiss_method: Mapped[str | None] = mapped_column(String(10), nullable=True)
