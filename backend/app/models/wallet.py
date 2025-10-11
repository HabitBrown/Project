from __future__ import annotations
from datetime import datetime
from typing import Optional
from sqlalchemy import BigInteger, Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from .base import Base

class WalletTransaction(Base):
    __tablename__ = "wallet_transactions"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    amount: Mapped[int] = mapped_column(Integer, nullable=False)  # +획득 / -차감
    reason: Mapped[str] = mapped_column(String(30), nullable=False)
    ref_table: Mapped[Optional[str]] = mapped_column(String(30))
    ref_id: Mapped[Optional[int]] = mapped_column(BigInteger)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
