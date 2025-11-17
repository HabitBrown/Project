# app/schemas/profile.py
from __future__ import annotations
from typing import Optional
from pydantic import BaseModel, Field


class ProfileOut(BaseModel):
    id: int
    nickname: Optional[str] = None
    bio: Optional[str] = None
    age: Optional[int] = None
    gender: str
    profile_picture: Optional[str] = None
    hb_balance: int

    class Config:
        from_attributes = True



class ProfileUpdateIn(BaseModel):
    nickname: Optional[str] = Field(default=None, max_length=30)
    bio: Optional[str] = Field(default=None, max_length=255)
    age: Optional[int] = None
    gender: Optional[str] = None  # "M", "F", "N"
