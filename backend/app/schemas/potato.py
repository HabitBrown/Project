# app/schemas/potato.py
from typing import List, Optional, Literal
from pydantic import BaseModel, ConfigDict


class HashSummary(BaseModel):
    hash_id: int
    title: str
    difficulty: int
    deadline: str              # "HH:MM"
    cert_type: Literal["photo", "text"]

    model_config = ConfigDict(from_attributes=True)


class FarmerSummary(BaseModel):
    user_id: int
    name: str
    bio: Optional[str] = ""
    tags: List[str] = []
    avatar_url: Optional[str] = None
    hashes: List[HashSummary] = []
    
    is_following: bool = False

    model_config = ConfigDict(from_attributes=True)
