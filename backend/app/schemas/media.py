# app/schemas/media.py
from datetime import datetime
from pydantic import BaseModel

class MediaAssetOut(BaseModel):
    id: int
    storage_url: str
    created_at: datetime

    class Config:
        from_attributes = True
