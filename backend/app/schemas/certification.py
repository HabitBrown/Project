# app/schemas/certification.py
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field

class CertificationCreateIn(BaseModel):
    user_habit_id: int
    method: str = Field(pattern="^(photo|text)$")
    text_content: Optional[str] = None
    photo_asset_id: Optional[int] = None

class CertificationOut(BaseModel):
    id: int
    user_habit_id: int
    method: str
    text_content: Optional[str]
    photo_asset_id: Optional[int]
    status: str
    ts_utc: datetime

    class Config:
        from_attributes = True  # orm_mode 대체
