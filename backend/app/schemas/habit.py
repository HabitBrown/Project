# app/schemas/habit.py
from datetime import date, time, datetime
from typing import Optional
from pydantic import BaseModel


class HabitSearchItemOut(BaseModel):
    user_habit_id: int
    owner_id: int
    owner_nickname: Optional[str]
    title: str
    method: str        # "photo" / "text"
    difficulty: int    # 난이도(해시 개수)
    period_start: date
    period_end: date
    deadline_local: time

    class Config:
        orm_mode = True


class HabitCreateIn(BaseModel):
    title: str
    method: str     # "photo" | "text"
    days_of_week: int
    period_start: date
    period_end: date
    deadline_local: time
    difficulty: int = 1
    source_habit_id: Optional[int] = None
    
class CompletedHabitItemOut(BaseModel):
    user_habit_id: int
    title: str
    method: str
    difficulty: int
    period_start: date
    period_end: date

    # 모델에 추가해둔 상태/완료일 필드 사용
    status: str
    completed_at: Optional[datetime] = None

    class Config:
        orm_mode = True