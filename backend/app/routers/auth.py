# app/routers/auth.py
from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

# ▶ 프로젝트 임포트 경로 맞게 조정: app.* 또는 backend.app.*
from app.database import get_db
from app.models.user import User

router = APIRouter(prefix="/auth", tags=["Auth"])

@router.get("/nicknames/check")
def check_nickname(
    nickname: str = Query(..., min_length=1, description="중복 확인할 닉네임"),
    db: Session = Depends(get_db)
):
    exists = db.scalar(select(User.id).where(User.nickname == nickname.strip()))
    return {"available": exists is None}
