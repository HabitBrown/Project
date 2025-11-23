# app/schemas/exchange.py
from datetime import date, time, datetime
from typing import List, Literal, Optional
from pydantic import BaseModel, Field

class ExchangeRequestCreate(BaseModel):
    target_habit_id: int

    # 1=월 ... 7=일, 최소 3개
    weekdays: List[int] = Field(..., min_length=3)

    start_date: date
    end_date: date

    deadline: time

    difficulty: int = Field(..., ge=1, le=5)
    method: Literal["photo", "text"]

class ExchangeRequestOut(BaseModel):
    id: int
    from_user_id: int
    to_user_id: int
    target_habit_id: int

    method: str
    deadline_local: time
    days_of_week: int
    start_date: date
    end_date: date
    difficulty: int

    status: str
    created_at: datetime
    decided_at: Optional[datetime] = None

    class Config:
        from_attributes = True   # SQLAlchemy 모델 → 응답 변환용

class ReceivedFromUser(BaseModel):
    id: int
    nickname: str
    profile_picture: Optional[str] = None

class ReceivedTargetHabit(BaseModel):
    habit_id: int
    title: str
    difficulty: int

class ReceivedExchangeItem(BaseModel):
    request_id: int
    from_user: ReceivedFromUser
    target_habit: ReceivedTargetHabit
    
class ExchangeAcceptIn(BaseModel):
    opponent_user_habit_id: int