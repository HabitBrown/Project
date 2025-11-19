# app/schemas/interest.py
from __future__ import annotations
from typing import List
from pydantic import BaseModel

class InterestOut(BaseModel):
    id: int
    name: str

    class Config:
        from_attributes = True


class UserInterestsOut(BaseModel):
    user_id: int
    interests: List[InterestOut]
