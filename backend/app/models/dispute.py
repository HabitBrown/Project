from __future__ import annotations
from datetime import datetime
from typing import Optional
from sqlalchemy import BigInteger, String, DateTime, ForeignKey, Enum
from sqlalchemy.orm import Mapped, mapped_column
from .base import Base

class Dispute(Base):
    __tablename__ = "disputes"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    certification_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("certifications.id", ondelete="CASCADE"), nullable=False)
    raised_by: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    reason_code: Mapped[str] = mapped_column(String(30), nullable=False)
    detail: Mapped[Optional[str]] = mapped_column(String(255))
    status: Mapped[str] = mapped_column(Enum("open", "accepted", "rejected", "expired", name="dispute_status_enum"), default="open", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    decided_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
