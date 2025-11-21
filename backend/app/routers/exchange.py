# app/routers/exchange.py

from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.models.habit import Habit
from app.models.exchange import ExchangeRequest
from app.schemas.exchange import ExchangeRequestCreate, ExchangeRequestOut
from app.routers.register import get_current_user  # 실제 경로에 맞게 수정

router = APIRouter(
    prefix="/exchange-requests",
    tags=["Exchange"],
)


def _encode_days_of_week(weekdays: List[int]) -> int:
    """
    [1,3,5] -> 비트마스크 정수.
    1=월, ... , 7=일
    """
    mask = 0
    for d in weekdays:
        if 1 <= d <= 7:
            mask |= (1 << (d - 1))
    return mask


@router.post(
    "",
    response_model=ExchangeRequestOut,
    status_code=status.HTTP_201_CREATED,
)
def create_exchange_request(
    payload: ExchangeRequestCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):

    """
    교환 요청 보내기 (pending 상태의 요청만 생성).
    - from_user_id: 현재 유저
    - to_user_id  : target_habit 의 owner
    """

    # 1) 대상 습관 존재 확인
    habit = db.get(Habit, payload.target_habit_id)
    if not habit:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="해당 습관을 찾을 수 없습니다.",
        )
        

    # 자기 습관에는 교환 요청 금지
    if habit.owner_user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="자신의 습관에는 교환 요청을 보낼 수 없습니다.",
        )

    to_user_id = habit.owner_user_id

    # 2) 요일 검증 (1~7, 최소 3개)
    weekdays = sorted(set(payload.weekdays))
    if len(weekdays) < 3:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="요일은 최소 3개 이상 선택해야 합니다.",
        )
    if any(d < 1 or d > 7 for d in weekdays):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="요일 값은 1(월)~7(일) 범위여야 합니다.",
        )
    days_mask = _encode_days_of_week(weekdays)

    # 3) 기간 검증 (프론트에서 계산해서 줌, 그래도 한 번 체크)
    if payload.start_date > payload.end_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="시작일이 종료일보다 늦을 수 없습니다.",
        )

    # 4) 난이도 / 인증 방식 검증 (프론트 값 범위만 체크)
    if not (1 <= payload.difficulty <= 5):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="난이도는 1~5 사이여야 합니다.",
        )
    if payload.method not in ("photo", "text"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="잘못된 인증 방식입니다.",
        )

    # 5) 같은 사람 → 같은 사람, 같은 습관, pending 중복 요청 방지
    exists = db.scalar(
        select(ExchangeRequest.id).where(
            ExchangeRequest.from_user_id == current_user.id,
            ExchangeRequest.to_user_id == to_user_id,
            ExchangeRequest.target_habit_id == payload.target_habit_id,
            ExchangeRequest.status == "pending",
        )
    )
    if exists:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="이미 대기 중인 교환 요청이 있습니다.",
        )

    # 6) 교환 요청 생성
    now = datetime.utcnow()

    req = ExchangeRequest(
        from_user_id=current_user.id,
        to_user_id=to_user_id,
        target_habit_id=payload.target_habit_id,
        method=payload.method,
        deadline_local=payload.deadline,
        days_of_week=days_mask,
        start_date=payload.start_date,
        end_date=payload.end_date,
        difficulty=payload.difficulty,
        status="pending",
        created_at=now,
        decided_at=None,
    )

    db.add(req)
    db.commit()
    db.refresh(req)

    return req
