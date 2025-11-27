# app/models/attendance_log.py
from __future__ import annotations
from datetime import date, datetime
from typing import Optional

from sqlalchemy import BigInteger, Date, DateTime, ForeignKey, Integer, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base
from .user import User


class AttendanceLog(Base):
  __tablename__ = "attendance_logs"
  __table_args__ = (
    # 한 유저는 하루에 출석 1번만
    UniqueConstraint("user_id", "attend_date", name="uq_attendance_user_date"),
  )

  id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)

  user_id: Mapped[int] = mapped_column(
    BigInteger,
    ForeignKey("users.id", ondelete="CASCADE"),
    nullable=False,
  )

  # 출석한 날짜 (로컬 날짜 기준, 예: Asia/Seoul)
  attend_date: Mapped[date] = mapped_column(Date, nullable=False)

  # 그 날 출석 기준 연속 출석 일수 (1~7)
  streak: Mapped[int] = mapped_column(Integer, nullable=False)

  # 그 날 지급된 보상 (기본 1, 7일째는 6)
  reward: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

  created_at: Mapped[datetime] = mapped_column(
    DateTime,
    nullable=False,
    default=datetime.utcnow,
  )

  user: Mapped[User] = relationship("User", backref="attendance_logs")
