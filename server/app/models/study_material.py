from datetime import datetime

from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Index, Integer, String, Text, func, text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class StudyMaterial(Base):
    __tablename__ = "study_materials"
    __table_args__ = (
        # 세트당 메인 자료 1개 강제 (부분 UNIQUE)
        Index(
            "uq_study_materials_set_id_main",
            "set_id",
            unique=True,
            postgresql_where=text("is_main = true"),
        ),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    set_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("material_sets.id", ondelete="CASCADE"), nullable=False
    )
    is_main: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")
    file_name: Mapped[str] = mapped_column(String(255), nullable=False)
    s3_key: Mapped[str] = mapped_column(Text, nullable=False, unique=True)
    file_size_bytes: Mapped[int] = mapped_column(BigInteger, nullable=False)
    upload_status: Mapped[str] = mapped_column(String(12), nullable=False, server_default="pending")
    page_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    extracted_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
