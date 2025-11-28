# app/schemas/shop.py

from datetime import datetime
from typing import Optional
from pydantic import BaseModel


class ShopItemBase(BaseModel):
    id: int
    name: str
    price_hb: int
    category: Optional[str] = None
    image_url: Optional[str] = None

    class Config:
        from_attributes = True


class OrderBase(BaseModel):
    id: int
    user_id: int
    item_id: Optional[int]
    status: str
    created_at: datetime
    item: Optional[ShopItemBase]

    class Config:
        from_attributes = True


class OrderCreate(BaseModel):
    item_id: int
