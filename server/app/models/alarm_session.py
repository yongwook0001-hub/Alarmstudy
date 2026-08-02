from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, SmallInteger, String
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
    # 세션 시작 시 실제로 내려준 문제 수 스냅샷 (버퍼 부족으로 조정될 수 있어 전역
    # 상수를 그대로 쓰면 안 됨 — dismiss의 quiz 검증은 이 값을 기준으로 한다).
    # server_default는 마이그레이션 시점의 REQUIRED_CORRECT_COUNT(constants.py) 값.
    required_count: Mapped[int] = mapped_column(SmallInteger, nullable=False, server_default="3")
    # null=미해제 (별도 status 컬럼 없음)
    dismissed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    dismiss_method: Mapped[str | None] = mapped_column(String(10), nullable=True)
