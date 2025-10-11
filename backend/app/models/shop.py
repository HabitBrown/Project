from __future__ import annotations
from datetime import datetime
from typing import Optional
from sqlalchemy import BigInteger, Integer, String, DateTime, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base


class ShopItem(Base):
    __tablename__ = "shop_items"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    category: Mapped[Optional[str]] = mapped_column(String(30))
    name: Mapped[str] = mapped_column(String(60), nullable=False)
    price_hb: Mapped[int] = mapped_column(Integer, nullable=False)
    image_url: Mapped[Optional[str]] = mapped_column(String(255))

    # backref from Order
    orders: Mapped[list["Order"]] = relationship(back_populates="item")


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    item_id: Mapped[Optional[int]] = mapped_column(BigInteger, ForeignKey("shop_items.id", ondelete="SET NULL"))
    status: Mapped[str] = mapped_column(String(20), default="placed", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    # relationships
    item: Mapped[Optional["ShopItem"]] = relationship(back_populates="orders")
