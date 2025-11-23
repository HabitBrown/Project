# app/routers/duel.py
from datetime import date, datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.database import get_db
from app.routers.register import get_current_user

from app.models.duel import Duel
from app.models.user import User
from app.models.exchange import ExchangeRequest
from app.models.habit import Habit
from app.models.user_habit import UserHabit

from app.schemas.duel import ActiveDuelItem, DuelFromExchangeIn
router = APIRouter(prefix="/duels", tags=["duels"])


def _encode_days_of_week(weekdays: List[int]) -> int:
    mask = 0
    for d in weekdays:
        if 1 <= d <= 7:
            mask |= (1 << (d - 1))
    return mask

@router.get("/active", response_model=List[ActiveDuelItem])
def get_active_duels(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    today = date.today()

    duels = (
        db.query(Duel)
        .filter(
            Duel.status == "active",
            or_(
                Duel.owner_user_id == current_user.id,
                Duel.challenger_user_id == current_user.id
            )
        )
        .all()
    )

    items: list[ActiveDuelItem] = []

    for d in duels:
        # 이 듀얼에 연결된 UserHabit 두 개 가져오기
        duel_habits: list[UserHabit] = (
            db.query(UserHabit)
            .filter(UserHabit.duel_id == d.id)
            .all()
        )

        if len(duel_habits) < 2:
            # 데이터가 이상하면 스킵
            continue

        # 현재 유저 / 상대 유저 습관 분리
        my_uh = next((uh for uh in duel_habits if uh.user_id == current_user.id), None)
        rival_uh = next((uh for uh in duel_habits if uh.user_id != current_user.id), None)

        if not my_uh or not rival_uh:
            continue

        rival = db.get(User, rival_uh.user_id)
        if not rival:
            continue

        days = (today - d.start_date).days + 1
        if days < 1:
            days = 1

        items.append(
            ActiveDuelItem(
                duel_id=d.id,
                rival_id=rival.id,
                rival_nickname=rival.nickname or rival.name,
                rival_profile_picture=rival.profile_picture,
                days=days,
                my_habit_title=my_uh.title,         #  내 도전
                rival_habit_title=rival_uh.title,   #  상대 도전
            )
        )

    return items


@router.post("/from-exchange", status_code=status.HTTP_201_CREATED)
def create_duel_from_exchange(
    payload: DuelFromExchangeIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # 1) 교환 요청 가져오기
    ex = db.get(ExchangeRequest, payload.exchange_request_id)
    if not ex:
        raise HTTPException(status_code=404, detail="교환 요청을 찾을 수 없습니다.")

    # 내가 받은 요청인지 + 아직 pending 인지 확인
    if ex.to_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="이 교환 요청에 대한 권한이 없습니다.")
    if ex.status != "pending":
        raise HTTPException(status_code=400, detail="이미 처리된 교환 요청입니다.")

    # 2) 내 원본 습관 (상대가 원래 노리던 템플릿)
    owner_habit = db.get(Habit, ex.target_habit_id)
    if not owner_habit:
        raise HTTPException(status_code=404, detail="대상 습관을 찾을 수 없습니다.")

    # 3) 상대가 예전에 완료했던 UserHabit (바텀시트에서 선택한 것)
    opponent_uh = db.get(UserHabit, payload.opponent_user_habit_id)
    if not opponent_uh or opponent_uh.user_id != ex.from_user_id:
        raise HTTPException(status_code=400, detail="상대 완료 습관 정보가 올바르지 않습니다.")

    # (원하면 여기서 opponent_uh.status == "completed_success" 검증도 가능)

    # 4) 프론트에서 넘어온 값 검증/변환
    if payload.start_date > payload.end_date:
        raise HTTPException(status_code=400, detail="시작일이 종료일보다 늦을 수 없습니다.")

    days_mask = _encode_days_of_week(payload.days_of_week)

    if payload.method not in ("photo", "text"):
        raise HTTPException(status_code=400, detail="잘못된 인증 방식입니다.")

    now = datetime.now()

    # 5) Duel 생성 (기간/요일/마감시간은 프론트에서 설정한 값 사용)
    duel = Duel(
        owner_user_id=ex.to_user_id,
        challenger_user_id=ex.from_user_id,
        habit_title=f"{owner_habit.title} vs {opponent_uh.title}",          # 카드에 보여줄 제목
        method=payload.method,
        deadline_local=payload.deadline_local,
        days_of_week=days_mask,
        start_date=payload.start_date,
        end_date=payload.end_date,
        difficulty=payload.difficulty,
        status="active",
        created_at=now,
    )
    db.add(duel)
    db.flush()  # duel.id 확보

    # 6) Duel용 UserHabit 두 개 생성

    # 6-1) 나(도전 받은 사람) 쪽 습관
    owner_duel_habit = UserHabit(
        user_id=ex.to_user_id,               
        source_habit_id=opponent_uh.source_habit_id,  # 만보걷기의 원본 Habit.id
        title=opponent_uh.title,             # "만보걷기"
        method=payload.method,               # 메서드는 듀얼 설정값에 맞추는 게 자연스러움
        deadline_local=payload.deadline_local,
        days_of_week=days_mask,
        period_start=payload.start_date,
        period_end=payload.end_date,
        is_active=True,
        created_at=now,
        difficulty=payload.difficulty,
        status="active",
        duel_id=duel.id,
    )

    # 6-2) 상대(도전 건 사람) 쪽 습관
    challenger_duel_habit = UserHabit(
        user_id=ex.from_user_id,          
        source_habit_id=owner_habit.id,   # 코테 원본 Habit.id
        title=owner_habit.title,          # "코테 문제 1문제 풀기"
        method=payload.method,
        deadline_local=payload.deadline_local,
        days_of_week=days_mask,
        period_start=payload.start_date,
        period_end=payload.end_date,
        is_active=True,
        created_at=now,
        difficulty=payload.difficulty,
        status="active",
        duel_id=duel.id,
    )

    db.add_all([owner_duel_habit, challenger_duel_habit])

    # 7) 교환 요청 정리 (삭제 or 상태 변경)
    db.delete(ex)
    db.commit()

    # 프론트에서는 boolean만 보니까, 필요하면 duel_id 정도만 내려줘도 됨
    return {"duel_id": duel.id}