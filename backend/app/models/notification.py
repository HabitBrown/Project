from __future__ import annotations
from datetime import datetime
from typing import Optional
from sqlalchemy import BigInteger, String, Boolean, DateTime, ForeignKey, Enum
from sqlalchemy.orm import Mapped, mapped_column
from .base import Base

class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    type: Mapped[str] = mapped_column(Enum("challenge","challenge_accepted","challenge_rejected","cert_success","cert_fail","dispute","system", name="noti_type_enum"), nullable=False)
    title: Mapped[Optional[str]] = mapped_column(String(80))
    body: Mapped[Optional[str]] = mapped_column(String(255))
    deeplink: Mapped[Optional[str]] = mapped_column(String(120))
    is_read: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
