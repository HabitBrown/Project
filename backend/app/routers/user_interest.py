# app/routers/user_interest.py
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import select

from app.database import get_db
from app.models.user import User, Interest, UserInterest
from app.schemas.interest import UserInterestsOut, InterestOut

router = APIRouter(prefix="/users", tags=["Interests"])


@router.get("/{user_id}/interests", response_model=UserInterestsOut)
def get_user_interests(user_id: int, db: Session = Depends(get_db)):
    # 1) 유저 존재 여부 확인
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")

    # 2) user_interests + interests 조인해서 관심사 목록 조회
    stmt = (
        select(Interest)
        .join(UserInterest, UserInterest.interest_id == Interest.id)
        .where(UserInterest.user_id == user_id)
        .order_by(Interest.id)
    )

    interests = db.scalars(stmt).all()

    # 3) 스키마 형태로 리턴
    return UserInterestsOut(
        user_id=user_id,
        interests=interests,
    )
