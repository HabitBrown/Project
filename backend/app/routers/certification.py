# app/routers/certifications.py
from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.database import SessionLocal
from app.models.user import User
from app.models.user_habit import UserHabit
from app.models.certification import Certification
from app.schemas.certification import CertificationCreateIn, CertificationOut
from app.routers.register import get_current_user

router = APIRouter(prefix="/certifications", tags=["Certifications"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.post("", response_model=CertificationOut, status_code=status.HTTP_201_CREATED)
def create_certification(
    body: CertificationCreateIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    습관 인증 기록 하나 생성
    - method: "photo" or "text" (UserHabit.method와 동일해야 함)
    - text_content / photo_asset_id 는 method에 따라 선택적으로 사용
    """

    # 1) 해당 UserHabit이 내 것인지 확인
    user_habit = (
        db.query(UserHabit)
        .filter(
            UserHabit.id == body.user_habit_id,
            UserHabit.user_id == current_user.id,
        )
        .first()
    )
    if not user_habit:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="해당 ID의 내 습관을 찾을 수 없습니다.",
        )

    # 2) method 일치 여부 체크 (백엔드 방어)
    if user_habit.method != body.method:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"이 습관은 '{user_habit.method}' 방식으로만 인증할 수 있습니다.",
        )

    # 3) method 별 필수 필드 검증
    if body.method == "text" and not body.text_content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="글 인증일 때는 text_content가 필요합니다.",
        )
    if body.method == "photo" and not body.photo_asset_id:
        # 1단계에서는 나중에 media 업로드 완성되면 사용
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="사진 인증일 때는 photo_asset_id가 필요합니다.",
        )

    # 4) Certification 생성
    now_utc = datetime.now(timezone.utc)
    cert = Certification(
        user_id=current_user.id,
        user_habit_id=user_habit.id,
        duel_id=user_habit.duel_id,
        ts_utc=now_utc,
        method=body.method,
        text_content=body.text_content,
        photo_asset_id=body.photo_asset_id,
        status="success",  # 일단 성공으로만 저장 (나중에 실패도 추가 가능)
        fail_reason=None,
    )

    db.add(cert)

    # (여기서 나중에 "성공 습관으로 승급 체크" 하는 함수를 호출할 수도 있음)
    db.commit()
    db.refresh(cert)

    return cert

@router.get("/today/habits", response_model=List[int])
def get_today_certified_habits(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    오늘(한국 시간 기준)에 인증 성공한 user_habit_id 목록 반환
    """

    # 1) 오늘 날짜 범위 (KST → UTC 변환)
    KST = timezone(timedelta(hours=9))
    now_kst = datetime.now(KST)
    start_kst = datetime(now_kst.year, now_kst.month, now_kst.day, tzinfo=KST)
    end_kst = start_kst + timedelta(days=1)

    start_utc = start_kst.astimezone(timezone.utc)
    end_utc = end_kst.astimezone(timezone.utc)

    # 2) 해당 유저 + 오늘 + 성공한 인증만 조회
    q = (
        db.query(Certification.user_habit_id)
        .filter(
            Certification.user_id == current_user.id,
            Certification.status == "success",
            Certification.ts_utc >= start_utc,
            Certification.ts_utc < end_utc,
        )
        .distinct()
    )

    rows = q.all()
    # rows는 [(1,), (3,), (7,)] 이런 형태라서 첫 칼럼만 꺼내줌
    habit_ids = [r[0] for r in rows if r[0] is not None]

    return habit_ids