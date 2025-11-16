from __future__ import annotations
from datetime import datetime, date, time
from typing import Optional
from sqlalchemy import (
    BigInteger, String, SmallInteger, Boolean,
    Date, Time, DateTime, ForeignKey, Enum, Index
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from .base import Base

class UserHabit(Base):
    __tablename__ = "user_habits"
    __table_args__ = (
        Index("idx_user_habits_user", "user_id"),
        Index("idx_user_habits_dow", "days_of_week"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    source_habit_id: Mapped[Optional[int]] = mapped_column(BigInteger, ForeignKey("habits.id"))
    title: Mapped[str] = mapped_column(String(50), nullable=False)
    method: Mapped[str] = mapped_column(Enum("photo", "text", name="auth_method_enum"), nullable=False)
    deadline_local: Mapped[time] = mapped_column(Time, nullable=False)
    days_of_week: Mapped[int] = mapped_column(SmallInteger, nullable=False)  # bitmask
    period_start: Mapped[date] = mapped_column(Date, nullable=False)
    period_end: Mapped[date] = mapped_column(Date, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    difficulty: Mapped[int] = mapped_column(SmallInteger, default=1, nullable=False)
    
    duel_id: Mapped[Optional[int]] = mapped_column(
        BigInteger,
        ForeignKey("duels.id", ondelete="SET NULL"),
        nullable=True,
    )