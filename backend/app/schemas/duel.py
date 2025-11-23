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
    
class DuelConversationMessage(BaseModel):

    id: int
    user_id: int
    user_habit_id: Optional[int]
    duel_id: Optional[int]
    habit_title: str  # user_habits.title
    method: Optional[str]  # "photo" / "text" / 실패면 None 가능
    status: str            # "success" / "fail"
    fail_reason: Optional[str]
    text_content: Optional[str]
    photo_asset_id: Optional[int]
    
    photo_url: Optional[str] = None
    
    ts_utc: datetime

    class Config:
        from_attributes = True  # 직접 dict 만들어서 넣을 거라 False로 둠
        
        
class DuelConversationOut(BaseModel):
    """
    HashFightPage 하나를 구성하는 전체 응답
    """
    duel_id: int

    partner_id: int
    partner_nickname: str
    partner_profile_picture: Optional[str] = None

    remain_fail_count: int

    messages: List[DuelConversationMessage]