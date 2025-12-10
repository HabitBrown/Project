from __future__ import annotations
from datetime import datetime, date, time
from typing import Optional
from sqlalchemy import (
    BigInteger, Integer, SmallInteger, String,
    Date, Time, DateTime, ForeignKey, Enum, Index
)
from sqlalchemy.orm import Mapped, mapped_column
from .base import Base

class Duel(Base):
    __tablename__ = "duels"
    __table_args__ = (Index("idx_duels_pair", "owner_user_id", "challenger_user_id", "status"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    owner_user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    challenger_user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    habit_title: Mapped[str] = mapped_column(String(50), nullable=False)
    method: Mapped[str] = mapped_column(Enum("photo", "text", name="duel_method_enum"), nullable=False)
    deadline_local: Mapped[time] = mapped_column(Time, nullable=False)
    days_of_week: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date] = mapped_column(Date, nullable=False)
    
    difficulty: Mapped[int] = mapped_column(SmallInteger, default=1, nullable=False)
    
    owner_stake: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    challenger_stake: Mapped[int] = mapped_column(SmallInteger, nullable=False)

    
    status: Mapped[str] = mapped_column(Enum("pending", "active", "finished", "canceled", name="duel_status_enum"), default="pending", nullable=False)
    result: Mapped[Optional[str]] = mapped_column(Enum("owner_win", "challenger_win", "draw", "forfeit_owner", "forfeit_challenger", name="duel_result_enum"))
    owner_success_cnt: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    challenger_success_cnt: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    grace_minutes: Mapped[int] = mapped_column(SmallInteger, default=5, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
