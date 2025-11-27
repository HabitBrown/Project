# app/routers/duel.py
from datetime import date, datetime, timezone
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_, select, func
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

FAIL_LIMIT = 3 

router = APIRouter(prefix="/duels", tags=["duels"])


def _encode_days_of_week(weekdays: List[int]) -> int:
    mask = 0
    for d in weekdays:
        if 1 <= d <= 7:
            mask |= (1 << (d - 1))
    return mask

def _forfeit_duel(
    db: Session,
    duel: Duel,
    loser_user_id: int,
) -> None:
    """
    포기 / 실패 초과 등으로 한 쪽이 패배했을 때:
    - 진 사람: completed_fail + is_active=False + completed_at
    - 이긴 사람: 계속 개인 습관 도전 (status는 active 유지, duel_id만 제거)
    - Duel: finished + result=forfeit_owner / forfeit_challenger
    """
    if duel.status != "active":
        return

    now_utc = datetime.now(timezone.utc)

    stake = duel.difficulty
    owner_user = db.get(User, duel.owner_user_id)
    challenger_user = db.get(User, duel.challenger_user_id)
    
    if owner_user is not None and challenger_user is not None:
        # 패배자/승자 결정
        if loser_user_id == duel.owner_user_id:
            winner_user = challenger_user
        else:
            winner_user = owner_user

        # 이미 둘 다 스테이크만큼 차감된 상태에서,
        # 승자에게 양쪽 스테이크(2배)를 지급 → 순이익 +stake
        winner_user.hb_balance += stake * 2
        
    # duel에 연결된 user_habits 두 개 가져오기
    duel_habits: list[UserHabit] = (
        db.query(UserHabit)
        .filter(UserHabit.duel_id == duel.id)
        .all()
    )

    for uh in duel_habits:
        if uh.user_id == loser_user_id:
            # 패배한 쪽: 실패로 종료
            uh.status = "completed_fail"
            uh.is_active = False
            uh.completed_at = now_utc
            # duel_id는 굳이 지워도 되고 안 지워도 되지만, 깔끔하게 None
            uh.duel_id = None
        else:
            # 이긴 쪽: duel 관계만 끊고 개인 습관 도전으로 이어가기
            uh.duel_id = None
            # status / is_active 는 기존(active) 그대로 둔다

    duel.status = "finished"
    if loser_user_id == duel.owner_user_id:
        duel.result = "forfeit_owner"
    else:
        duel.result = "forfeit_challenger"

def _finish_duel_both_end(
    db: Session,
    duel: Duel,
    owner_status: str,
    challenger_status: str,
    result: str,
) -> None:
    """
    둘 다 끝나는 케이스(예: 1달 지나서 둘 다 성공 / 둘 다 실패 등)
    - 두 사람 모두 is_active=False + completed_at
    - status 는 인자로 받은 값으로 설정
    - duel.status="finished", duel.result=전달값
    """
    if duel.status != "active":
        return

    now_utc = datetime.now(timezone.utc)
    
    stake = duel.difficulty
    owner_user = db.get(User, duel.owner_user_id)
    challenger_user = db.get(User, duel.challenger_user_id)

    if owner_user is not None and challenger_user is not None:
        # 1) 둘 다 성공
        if owner_status == "completed_success" and challenger_status == "completed_success":
            owner_user.hb_balance += stake * 2
            challenger_user.hb_balance += stake * 2

        # 2) 한쪽만 성공 (혹시 이 함수로 사용하는 경우 대비)
        elif owner_status == "completed_success" and challenger_status == "completed_fail":
            owner_user.hb_balance += stake * 2
        elif owner_status == "completed_fail" and challenger_status == "completed_success":
            challenger_user.hb_balance += stake * 2

        # 3) 둘 다 실패면 아무도 돌려받지 않음
        #    (owner_status == challenger_status == "completed_fail")
        #    정책을 바꾸고 싶으면 여기에서 처리 추가하면 됨.

    duel_habits: list[UserHabit] = (
        db.query(UserHabit)
        .filter(UserHabit.duel_id == duel.id)
        .all()
    )

    for uh in duel_habits:
        if uh.user_id == duel.owner_user_id:
            uh.status = owner_status
        elif uh.user_id == duel.challenger_user_id:
            uh.status = challenger_status
        else:
            # 이론상 없지만 방어
            continue

        uh.is_active = False
        uh.completed_at = now_utc
        uh.duel_id = None  # duel 종료됐으니 관계 끊기

    duel.status = "finished"
    duel.result = result

def _check_and_finish_duel_by_rules(
    db: Session,
    duel: Duel,
) -> None:
    """
    규칙에 따라 듀얼 종료 여부를 판단하고 필요 시 종료 처리.
    1) 인증 실패 횟수 FAIL_LIMIT 초과 → 진 쪽 completed_fail, 상대는 개인 도전
    2) end_date 지나도 여전히 active 이고, FAIL_LIMIT 초과자 없으면
       → 둘 다 completed_success 로 종료
    """
    if duel.status != "active":
        return

    today = date.today()

    # --- 1) 유저별 실패 횟수 계산 ---
    rows = (
        db.query(
            Certification.user_id,
            func.count(Certification.id).label("fail_count") # pylint: disable=not-callable
        )
        .filter(
            Certification.duel_id == duel.id,
            Certification.status == "fail",
        )
        .group_by(Certification.user_id)
        .all()
    )

    fail_counts = {user_id: cnt for (user_id, cnt) in rows}

    owner_fail = fail_counts.get(duel.owner_user_id, 0)
    challenger_fail = fail_counts.get(duel.challenger_user_id, 0)

    # FAIL_LIMIT 초과한 사람 있는지
    owner_over = owner_fail > FAIL_LIMIT
    challenger_over = challenger_fail > FAIL_LIMIT

    if owner_over or challenger_over:
        # 둘 다 초과하면 둘 다 실패로 끝내고 draw 처리
        if owner_over and challenger_over:
            _finish_duel_both_end(
                db,
                duel,
                owner_status="completed_fail",
                challenger_status="completed_fail",
                result="draw",
            )
        elif owner_over:
            _forfeit_duel(db, duel, loser_user_id=duel.owner_user_id)
        else:
            _forfeit_duel(db, duel, loser_user_id=duel.challenger_user_id)

        db.commit()
        return

    # --- 2) 기간 종료 체크 ---
    # 아직 누구도 실패 초과 안 했고, 오늘이 end_date 지나갔다면 둘 다 성공 처리
    if today > duel.end_date:
        _finish_duel_both_end(
            db,
            duel,
            owner_status="completed_success",
            challenger_status="completed_success",
            result="draw",  # 둘 다 성공 → 무승부 처리
        )
        db.commit()
        return

@router.post("/{duel_id}/give-up", status_code=status.HTTP_200_OK)
def give_up_duel(
    duel_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    1번 케이스:
    - 해시톡방에서 포기 버튼을 누르면
      → 포기한 쪽은 completed_fail + is_active=False
      → 상대는 개인 습관 도전으로 계속
      → duel 은 finished + forfeit_* 결과
    """
    duel = db.get(Duel, duel_id)
    if duel is None:
        raise HTTPException(status_code=404, detail="Duel not found")

    if duel.status != "active":
        raise HTTPException(status_code=400, detail="이미 종료된 내기입니다.")

    if current_user.id not in (duel.owner_user_id, duel.challenger_user_id):
        raise HTTPException(status_code=403, detail="내기가 아닙니다.")

    # 현재 유저를 패배 처리
    _forfeit_duel(db, duel, loser_user_id=current_user.id)
    db.commit()

    return {"detail": "듀얼을 포기하였습니다."}


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

    # 3-1) 현재 내 해시로 이 난이도의 습관을 감당할 수 있는지 체크
    if opponent_uh.difficulty > current_user.hb_balance:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="해시가 부족해서 이 난이도의 습관에는 도전할 수 없습니다.",
        )

    # 3-2) 두 유저의 현재 해시 잔액이 스테이크 이상인지 확인
    stake = payload.difficulty
    
    owner_user = db.get(User, ex.to_user_id)
    challenger_user = db.get(User, ex.from_user_id)
    
    if owner_user is None or challenger_user is None:
        raise HTTPException(status_code=400, detail="내기 참가자 정보를 찾을 수 없습니다.")

    if owner_user.hb_balance < stake:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="내 해시가 부족해서 이 난이도로 내기를 시작할 수 없습니다.",
        )

        
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

    # 6-3) 내기 시작 시점에 양쪽 해시 차감
    owner_user.hb_balance -= stake
    
    if owner_user.hb_balance < 0 or challenger_user.hb_balance < 0:
        # 이론상 위에서 다 체크해서 여기 오면 음수가 될 일이 없지만
        # 혹시 동시성 문제를 대비해 한 번 더 안전장치.
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="해시 차감 중 오류가 발생했습니다.",
        )  
        
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

    _check_and_finish_duel_by_rules(db, duel)
    db.refresh(duel)
    
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