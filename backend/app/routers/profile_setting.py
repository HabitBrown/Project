# app/routers/profile_setting.py
from __future__ import annotations

import os
import uuid
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.schemas.profile import ProfileOut,ProfileUpdateIn

router = APIRouter(prefix="/users", tags=["Profile"])

ALLOWED_IMAGE_TYPES = {"image/png", "image/jpeg", "image/jpg", "image/webp"}
UPLOAD_ROOT = Path(os.getenv("HASHBROWN_UPLOAD_ROOT", "uploads")).resolve()

async def _save_image(file: UploadFile, subdir: str = "profile") -> str:
    if file.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(status_code=400, detail="지원하지 않는 이미지 형식입니다.")

    target_dir = (UPLOAD_ROOT / subdir)
    target_dir.mkdir(parents=True, exist_ok=True)

    ext = {
        "image/png": "png",
        "image/jpeg": "jpg",
        "image/jpg": "jpg",
        "image/webp": "webp",
    }[file.content_type]

    fname = f"{uuid.uuid4().hex}.{ext}"
    fpath = target_dir / fname

    with fpath.open("wb") as out:
        while True:
            chunk = await file.read(1024 * 1024)
            if not chunk:
                break
            out.write(chunk)

    return f"/uploads/{subdir}/{fname}"



def _get_user_or_404(db: Session, user_id: int) -> User:
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")
    return user



@router.get("/{user_id}/profile", response_model=ProfileOut)
def get_profile(user_id: int, db: Session = Depends(get_db)):
    user = _get_user_or_404(db, user_id)
    return user


@router.put("/{user_id}/profile", response_model=ProfileOut)
def update_profile(user_id: int, payload: ProfileUpdateIn, db: Session = Depends(get_db)):
    user = _get_user_or_404(db, user_id)

    if payload.nickname is not None:
        user.nickname = payload.nickname
    if payload.bio is not None:
        user.bio = payload.bio
    if payload.age is not None:
        user.age = payload.age
    if payload.gender is not None:
        user.gender = payload.gender

    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post("/{user_id}/profile-picture", response_model=ProfileOut, status_code=status.HTTP_201_CREATED)
async def upload_profile_picture(
    user_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    user = _get_user_or_404(db, user_id)
    public_url = await _save_image(file, subdir="profile")
    user.profile_picture = public_url

    db.add(user)
    db.commit()
    db.refresh(user)
    return user
