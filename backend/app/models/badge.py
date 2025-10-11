from __future__ import annotations
from datetime import datetime
from typing import Optional
from sqlalchemy import BigInteger, String, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from .base import Base

class Badge(Base):
    __tablename__ = "badges"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    description: Mapped[Optional[str]] = mapped_column(String(255))

class UserBadge(Base):
    __tablename__ = "user_badges"
    __table_args__ = (UniqueConstraint("user_id","badge_id", name="uq_user_badge"),)

    user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    badge_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("badges.id", ondelete="CASCADE"), primary_key=True)
    awarded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
