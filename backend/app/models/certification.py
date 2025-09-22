from __future__ import annotations
from datetime import datetime
from typing import Optional
from sqlalchemy import (
    BigInteger, String, Text, DateTime, ForeignKey, Enum, UniqueConstraint
)
from sqlalchemy.orm import Mapped, mapped_column
from .base import Base

class Certification(Base):
    __tablename__ = "certifications"
    __table_args__ = (UniqueConstraint("user_id", "user_habit_id", name="uq_cert_user_habit_day"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    user_habit_id: Mapped[Optional[int]] = mapped_column(BigInteger, ForeignKey("user_habits.id", ondelete="SET NULL"))
    duel_id: Mapped[Optional[int]] = mapped_column(BigInteger, ForeignKey("duels.id", ondelete="SET NULL"))
    ts_utc: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    method: Mapped[str] = mapped_column(Enum("photo", "text", name="cert_method_enum"), nullable=False)
    text_content: Mapped[Optional[str]] = mapped_column(Text)
    photo_asset_id: Mapped[Optional[int]] = mapped_column(BigInteger, ForeignKey("media_assets.id", ondelete="SET NULL"))
    status: Mapped[str] = mapped_column(Enum("success", "fail", name="cert_status_enum"), nullable=False)
    fail_reason: Mapped[Optional[str]] = mapped_column(String(100))
