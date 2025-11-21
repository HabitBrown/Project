from __future__ import annotations
from datetime import datetime, date, time
from typing import Optional
from sqlalchemy import BigInteger, String, DateTime, ForeignKey, Index, SmallInteger, Date, Time, Enum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from .base import Base

class ExchangeRequest(Base):
    __tablename__ = "exchange_requests"
    __table_args__ = (
        # 내가 받은 요청 목록 조회용 인덱스
        Index("idx_exchange_to", "to_user_id", "status"),
        # 내가 보낸 요청 목록 조회용 (향후 사용)
        Index("idx_exchange_from", "from_user_id", "status"),
    )
    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    # 누가 → 누구에게
    from_user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    to_user_id: Mapped[int] = mapped_column(
        BigInteger, 
        ForeignKey("users.id", ondelete="CASCADE"), 
        nullable=False,
    )
    # 어떤 습관을 대상으로 한 교환인지 (상대의 습관)
    target_habit_id: Mapped[int] = mapped_column(
        BigInteger, 
        ForeignKey("habits.id", ondelete="CASCADE"),
        nullable=False
    )
    # 상대가 정해놓은 인증 방식과 동일하게 사용 (photo / text)
    method: Mapped[str] = mapped_column(
        Enum("photo", "text", 
        name="exchange_method_enum"),
        nullable=False,
    )
    
    # 인증 마감 시간 (로컬 기준)
    deadline_local: Mapped[time] = mapped_column(Time, nullable=False)
    
    # 진행 요일 (bitmask, UserHabit.days_of_week와 동일)
    days_of_week: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    
    # 내기 기간 (프론트에서 계산해서 넘어오는 값)
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date] = mapped_column(Date, nullable=False)
    
    # 상대 난이도 = 걸 해시 개수 (1~5)
    difficulty: Mapped[int] = mapped_column(
        SmallInteger,
        default=1,
        nullable=False,
    )
    
    # 교환 요청 상태
    status: Mapped[str] = mapped_column(
        String(16), 
        default="pending", # pending/accepted/rejected/canceled 
        nullable=False,
    )  
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    decided_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
