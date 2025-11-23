# app/schemas/duel.py
from datetime import date, datetime, time
from typing import Optional,List
from pydantic import BaseModel, conint


class ActiveDuelItem(BaseModel):
    duel_id: int

    rival_id: int
    rival_nickname: str
    rival_profile_picture: Optional[str] = None

    # 오늘 기준 몇 일째인지 (start_date ~ 오늘)
    days: int

    my_habit_title: str
    rival_habit_title: str

    class Config:
        from_attributes = True

class DuelFromExchangeIn(BaseModel):
    exchange_request_id: int
    opponent_user_habit_id: int
    start_date: date
    end_date: date
    days_of_week: List[conint(ge=1, le=7)]  # [1~7]
    deadline_local: time                    # "HH:MM:SS" 문자열도 자동 파싱됨
    difficulty: conint(ge=1, le=5)
    method: str  # "photo" or "text"