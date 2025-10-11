from __future__ import annotations
from datetime import datetime
from typing import Optional
from sqlalchemy import BigInteger, String, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from .base import Base

class MediaAsset(Base):
    __tablename__ = "media_assets"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    uploader_id: Mapped[Optional[int]] = mapped_column(BigInteger, ForeignKey("users.id", ondelete="SET NULL"))
    storage_url: Mapped[str] = mapped_column(String(255), nullable=False)
    exif_taken_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    sha256: Mapped[Optional[str]] = mapped_column(String(64))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
