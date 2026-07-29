from datetime import datetime, time

from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, SmallInteger, String, Time, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Alarm(Base):
    __tablename__ = "alarms"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    # null=일반 알람. 세트 삭제 시 SET NULL로 강등 (하드삭제 아님)
    set_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("material_sets.id", ondelete="SET NULL"), nullable=True
    )
    alarm_time: Mapped[time] = mapped_column(Time, nullable=False)
    repeat_days: Mapped[int] = mapped_column(SmallInteger, nullable=False, server_default="0")
    is_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true")
    label: Mapped[str | None] = mapped_column(String(50), nullable=True)
    sound: Mapped[str] = mapped_column(String(50), nullable=False, server_default="default")
    volume: Mapped[int] = mapped_column(SmallInteger, nullable=False, server_default="80")
    is_vibration: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )
