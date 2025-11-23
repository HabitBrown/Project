# app/routers/duel.py
from datetime import date, datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.database import get_db
from app.routers.register import get_current_user
from app.routers.certification import auto_fail_overdue_habits_for_today

from app.models.duel import Duel
from app.models.user import User
from app.models.exchange import ExchangeRequest
from app.models.habit import Habit
from app.models.user_habit import UserHabit
from app.models.certification import Certification
from app.models.media import MediaAsset

from app.schemas.duel import(
    ActiveDuelItem, DuelFromExchangeIn,
    DuelConversationOut,DuelConversationMessage)

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

    # 2) 내 원본 습관 템플릿 (상대가 노렸던 Habit)
    owner_habit = db.get(Habit, ex.target_habit_id)
    if not owner_habit:
        raise HTTPException(status_code=404, detail="대상 습관을 찾을 수 없습니다.")

    # 3) 상대가 예전에 완료했던 UserHabit (바텀시트에서 내가 선택한 것)
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

    # ---------------------------------------------------
    # 🔐 각자 사용할 인증 방식(method) 결정
    # ---------------------------------------------------
    #
    # - owner(현재 사용자, ex.to_user_id)는 "상대(opponent_uh)가 했던 방식" 으로
    # - challenger(도전 건 사람, ex.from_user_id)는 "내 원래 습관 방식" 으로
    #

    # 4-1) 내가 도전할 상대 습관의 방식 (상대가 예전에 쓰던 방식)
    owner_side_method = opponent_uh.method  # 예: 상대가 text였다면 나도 text로 도전

    # 4-2) 상대가 도전할 내 습관의 방식
    #      → 내 user_id + owner_habit.id 를 source_habit_id 로 가진 과거 UserHabit 을 찾아서 method 사용
    my_original_uh = (
        db.query(UserHabit)
        .filter(
            UserHabit.user_id == ex.to_user_id,          # 나(교환 요청 받은 사람)
            UserHabit.source_habit_id == owner_habit.id, # 내가 가진 이 습관의 과거 UserHabit
            UserHabit.status == "completed_success",
        )
        .order_by(UserHabit.created_at.desc())
        .first()
    )

    if my_original_uh is not None:
        challenger_side_method = my_original_uh.method
    else:
        # 혹시 과거 completed_success 기록이 없다면
        # 일단 교환 요청에 저장된 method 나 상대 방식 중 하나로 fallback
        challenger_side_method = payload.method  # 또는 owner_side_method 로 바꿔도 됨

    # 5) Duel 생성 (듀얼 자체의 method 필드는 큰 의미 없으니 기존대로 payload.method 사용)
    duel = Duel(
        owner_user_id=ex.to_user_id,
        challenger_user_id=ex.from_user_id,
        habit_title=f"{owner_habit.title} vs {opponent_uh.title}",  # 카드에 보여줄 제목
        method=payload.method,               # 듀얼 전체 표기는 payload 기준으로 두고,
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

    # ---------------------------------------------------
    # 6) Duel용 UserHabit 두 개 생성 (여기가 핵심)
    # ---------------------------------------------------

    # 6-1) 나(도전 받은 사람, ex.to_user_id) 쪽 습관
    #      → 상대가 예전에 하던 습관(opponent_uh)을 "상대 방식" 그대로 따라함
    owner_duel_habit = UserHabit(
        user_id=ex.to_user_id,                      # 나
        source_habit_id=opponent_uh.source_habit_id,
        title=opponent_uh.title,
        method=owner_side_method,                   # ✅ 상대가 쓰던 method (ex: text)
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

    # 6-2) 상대(도전 건 사람, ex.from_user_id) 쪽 습관
    #      → 내가 원래 하던 습관(owner_habit)을 "내 방식" 그대로 따라함
    challenger_duel_habit = UserHabit(
        user_id=ex.from_user_id,                    # 상대
        source_habit_id=owner_habit.id,
        title=owner_habit.title,
        method=challenger_side_method,              # ✅ 내가 예전에 하던 method (ex: photo)
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

    return {"duel_id": duel.id}

@router.get("/{duel_id}/conversation", response_model=DuelConversationOut)
def get_duel_conversation(
    duel_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    
    auto_fail_overdue_habits_for_today(db, current_user)
    
    # 1) duel 존재 & 내가 참가자인지 확인
    duel = db.get(Duel, duel_id)
    if duel is None:
        raise HTTPException(status_code=404, detail="Duel not found")

    if current_user.id not in (duel.owner_user_id, duel.challenger_user_id):
        # 내가 아닌 사람의 대화방은 볼 수 없음
        raise HTTPException(status_code=403, detail="Not a participant of this duel")

    # 2) 상대방(파트너) 정보 결정
    if current_user.id == duel.owner_user_id:
        partner_id = duel.challenger_user_id
    else:
        partner_id = duel.owner_user_id

    partner: User | None = db.get(User, partner_id)
    if partner is None:
        raise HTTPException(status_code=404, detail="Partner user not found")

    # 3) 이 duel에 속한 user_habits 불러와서 {id: title} 맵 만들기
    user_habits = db.scalars(
        select(UserHabit).where(UserHabit.duel_id == duel.id)
    ).all()
    habit_title_map: dict[int, str] = {
        uh.id: uh.title for uh in user_habits
    }

    # 4) 이 duel에 대한 모든 Certification 시간순으로 가져오기
    certs = db.scalars(
        select(Certification)
        .where(Certification.duel_id == duel.id)
        .order_by(Certification.ts_utc.asc())
    ).all()

    asset_map: dict[int, str] = {}
    asset_ids = [c.photo_asset_id for c in certs if c.photo_asset_id is not None]
    if asset_ids:
        media_rows = (
            db.query(MediaAsset)
            .filter(MediaAsset.id.in_(asset_ids))
            .all()
        )
        asset_map = {m.id: m.storage_url for m in media_rows}
    
    # 5) 남은 실패 가능 횟수 계산 (정책에 맞게 수정 가능)
    #    예: 한 사람당 최대 3번까지 실패 가능이라고 가정
    FAIL_LIMIT = 3
    my_fail_count = sum(
        1
        for c in certs
        if c.user_id == current_user.id and c.status == "fail"
    )
    remain_fail_count = max(0, FAIL_LIMIT - my_fail_count)

    # 6) Certification -> DuelConversationMessage 변환
    messages: list[DuelConversationMessage] = []
    for c in certs:
        habit_title = habit_title_map.get(c.user_habit_id or 0, "")

        photo_url: str | None = None
        if c.photo_asset_id is not None:
            asset = db.get(MediaAsset, c.photo_asset_id)
            if asset is not None:
                photo_url = asset.storage_url
                
        messages.append(
            DuelConversationMessage(
                id=c.id,
                user_id=c.user_id,
                user_habit_id=c.user_habit_id,
                duel_id=c.duel_id,
                habit_title=habit_title,
                method=c.method,
                status=c.status,
                fail_reason=c.fail_reason,
                text_content=c.text_content,
                photo_asset_id=c.photo_asset_id,
                photo_url=photo_url,
                ts_utc=c.ts_utc,
            )
        )

    # 7) 최종 응답 조립
    return DuelConversationOut(
        duel_id=duel.id,
        partner_id=partner.id,
        partner_nickname=partner.nickname,
        partner_profile_picture=partner.profile_picture,
        remain_fail_count=remain_fail_count,
        messages=messages,
    )