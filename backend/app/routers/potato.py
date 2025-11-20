# backend/app/routers/potato.py

from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session
from datetime import datetime, timezone

from app.database import get_db
from app.models.user import User,Follow
from app.routers.register import get_current_user # 네 프로젝트 구조에 맞게
from app.routers.select_user import UserInfo 
from app.schemas.potato import FarmerSummary

router = APIRouter(prefix="/potato",tags=["Potato"])

@router.get("/farmers", response_model=List[FarmerSummary])
def get_farmers(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    감자캐기 화면용: 나(current_user)를 제외한 다른 유저들을
    nickname/bio/관심사/만든 습관 목록 형태로 반환.
    """

    # 1) 나를 제외한 활성 유저들 가져오기 (조건은 프로젝트 정책에 맞게 수정 가능)
    users = db.scalars(
        select(User).where(User.id != current_user.id)
    ).all()
    
    # 2) 내가 팔로우한 사람들 followee_id 집합
    followed_ids = {
        f.followee_id
        for f in db.scalars(
            select(Follow).where(Follow.follower_id == current_user.id)
        ).all()
    }

    farmers: list[FarmerSummary] = []

    for u in users:
        ui = UserInfo(phone=u.phone)
        info = ui.select_user()

        # info가 None이면(전화번호로 조회 실패) 스킵
        if not info:
            continue
        
        info["is_following"] = u.id in followed_ids

        # info(dict)의 키가 스키마(FarmerSummary) 필드랑 같다고 가정
        farmers.append(FarmerSummary(**info))

    return farmers

@router.post("/farmers/{target_user_id}/follow")
def follow_farmer(
    target_user_id: int,
    db: Session = Depends(get_db),              # 필요 없으면 제거해도 됨
    current_user: User = Depends(get_current_user),
):
    # 자기 자신 팔로우 방지
    if target_user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="자기 자신은 팔로우할 수 없습니다.",
        )
    # 대상 유저 찾기
    target_user = db.scalars(
        select(User).where(User.id == target_user_id)
    ).first()
    
    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="대상 유저를 찾을 수 없습니다.",
        )
    
     # 이미 팔로우 중인지 확인
    existing = db.scalars(
        select(Follow).where(
            Follow.follower_id == current_user.id,
            Follow.followee_id == target_user.id,
        )
    ).first()
    
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="이미 팔로우 중입니다.",
        )
    follow = Follow(
        follower_id=current_user.id,
        followee_id=target_user.id,
        created_at=datetime.now(timezone.utc),
    )
    db.add(follow)
    db.commit()
    
    return {
        "message": "OK",
        "follower_id": follow.follower_id,
        "followee_id": follow.followee_id,
    }

@router.delete("/farmers/{target_user_id}/follow")
def unfollow_farmer(
    target_user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    팔로우 취소.
    follower_id = current_user.id
    followee_id = target_phone을 가진 유저
    """

    # 1) 대상 유저 찾기
    target_user = db.scalars(
        select(User).where(User.id == target_user_id)
    ).first()

    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="대상 유저를 찾을 수 없습니다.",
        )

    # 2) 팔로우 관계 찾기
    follow = db.scalars(
        select(Follow).where(
            Follow.follower_id == current_user.id,
            Follow.followee_id == target_user.id,
        )
    ).first()

    if not follow:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="팔로우 관계가 존재하지 않습니다.",
        )

    db.delete(follow)
    db.commit()

    return {"message": "UNFOLLOWED"}