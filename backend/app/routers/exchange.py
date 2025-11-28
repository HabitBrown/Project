# app/routers/exchange.py

from datetime import datetime,timezone
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.models.habit import Habit
from app.models.duel import Duel
from app.models.user_habit import UserHabit
from app.models.exchange import ExchangeRequest
from app.models.notification import Notification

from app.schemas.exchange import (
    ExchangeRequestCreate, 
    ExchangeRequestOut,
    ReceivedExchangeItem,
    ReceivedFromUser,
    ReceivedTargetHabit,
    ExchangeAcceptIn
    )

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

def _create_notification(
    db: Session,
    user_id: int,
    noti_type: str,
    title: str,
    body: str = "",
    deeplink: str | None = None,
):
    """
    공통 알림 생성 헬퍼.
    - noti_type: "challenge", "challenge_rejected", "challenge_accepted", "system" 등 문자열 정책은 자유.
    """
    now = datetime.now(timezone.utc)
    
    n = Notification(
        user_id=user_id,
        type=noti_type,
        title=title,
        body=body,
        is_read=False,
        deeplink=deeplink,
        created_at=now,
    )
    db.add(n)
    
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
        
    sender = db.get(User, current_user.id)
    # 4-1) 현재 가진 해시로 이 난이도를 감당 가능한지 체크
    if sender is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="사용자 정보를 찾을 수 없습니다.",
        )

    if sender.hb_balance < payload.difficulty:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="해시가 부족해서 이 난이도로 내기를 걸 수 없습니다.",
        )
    
    sender.hb_balance -= payload.difficulty
    
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
    
    sender = db.get(User, current_user.id)
    habit_title = habit.title
    
    _create_notification(
        db=db,
        user_id=to_user_id,
        noti_type="challenge",
        title=f"{sender.nickname or sender.name} 농부가 도전장을 보냈어요.",
        body=habit_title,
        deeplink=f"/exchange-requests/received",
    )
    
    db.commit()

    return req

@router.get("/received", response_model=List[ReceivedExchangeItem])
def get_received_exchange_requests(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    stmt = (
        select(ExchangeRequest, User, Habit, UserHabit)
        .join(User, ExchangeRequest.from_user_id == User.id)
        .join(Habit, ExchangeRequest.target_habit_id == Habit.id)
        .join(
            UserHabit,
            (UserHabit.user_id == ExchangeRequest.to_user_id) &
            (UserHabit.source_habit_id == ExchangeRequest.target_habit_id)
            & (UserHabit.status == "completed_success"),
            isouter=True,
        )
        .where(
            ExchangeRequest.to_user_id == current_user.id,
            ExchangeRequest.status == "pending",
        )
        .order_by(ExchangeRequest.created_at.desc())
    )

    rows = db.execute(stmt).all()

    results = []

    for req, from_user, habit, uh in rows:

        # 🔥 user_habits 값이 있으면 그걸 쓰고, 없으면 habit.title/difficulty 사용
        display_title = uh.title if uh is not None else habit.title
        display_difficulty = uh.difficulty if uh is not None else req.difficulty

        results.append(
            ReceivedExchangeItem(
                request_id=req.id,
                from_user=ReceivedFromUser(
                    id=from_user.id,
                    nickname=from_user.nickname,
                    profile_picture=from_user.profile_picture
                ),
                target_habit=ReceivedTargetHabit(
                    habit_id=habit.id,
                    title=display_title,
                    difficulty=display_difficulty
                )
            )
        )

    return results

@router.get("/{user_id}/completed-hashes")
def get_completed_hashes_for_exchange(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rows = (
        db.query(UserHabit)
        .filter(
            UserHabit.user_id == user_id,
            UserHabit.status == "completed_success",
        )
        .all()
    )

    result = []
    for uh in rows:
        if uh.source_habit_id is None:
            continue

        result.append({
            "user_habit_id": uh.id,
            "hash_id": uh.source_habit_id,   # Habit.id
            "title": uh.title,
            "difficulty": uh.difficulty
        })

    return result

@router.post("/{request_id}/reject", status_code=status.HTTP_204_NO_CONTENT)
def reject_exchange_request(
    request_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # 1) 요청 조회
    ex = db.get(ExchangeRequest, request_id)
    if not ex:
        raise HTTPException(status_code=404, detail="교환 요청을 찾을 수 없습니다.")

    # 2) 내가 받은 요청인지 + 아직 대기 상태인지 확인
    if ex.to_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="이 교환 요청에 대한 권한이 없습니다.")
    if ex.status != "pending":
        raise HTTPException(status_code=400, detail="이미 처리된 교환 요청입니다.")

    # 3) 대상 원본 Habit (상대가 원하는 나의 습관)
    habit = db.get(Habit, ex.target_habit_id)
    if not habit:
        raise HTTPException(status_code=404, detail="대상 습관을 찾을 수 없습니다.")

    # 여기서 "만보걷기 / 영어뉴스 듣기" 같은 이름을 찾아온다.
    latest_completed_uh = (
        db.query(UserHabit)
        .filter(
            UserHabit.user_id == ex.to_user_id,           # 나(도전 받은 사람)의 기록
            UserHabit.source_habit_id == habit.id,
            UserHabit.status == "completed_success",
        )
        .order_by(UserHabit.completed_at.desc())
        .first()
    )

    # 없으면 기본 템플릿 제목 사용
    display_title = latest_completed_uh.title if latest_completed_uh else habit.title

    now = datetime.now()
    stake = ex.difficulty
    sender = db.get(User, ex.from_user_id)
    if sender is not None:
        sender.hb_balance += stake

    # 4) 송강호(= from_user) 혼자 도전용 UserHabit 생성
    solo_habit = UserHabit(
        user_id=ex.from_user_id,
        source_habit_id=habit.id,
        title=display_title,
        method=ex.method,                 # photo/text
        deadline_local=ex.deadline_local,
        days_of_week=ex.days_of_week,
        period_start=ex.start_date,
        period_end=ex.end_date,
        is_active=True,
        created_at=now,
        difficulty=ex.difficulty,
        status="active",
        duel_id=None,
    )
    db.add(solo_habit)

    # 5) 교환 요청은 아예 삭제
    db.delete(ex)

    rejector = db.get(User, current_user.id)
    habit_title = display_title
    
    _create_notification(
        db=db,
        user_id=ex.from_user_id,               # 도전장을 보낸 사람
        noti_type="challenge_rejected",
        title=f"{rejector.nickname or rejector.name} 농부가 도전장을 거절했어요.",
        body=habit_title,
        deeplink="/exchange-requests/sent",    # 보낸 사람이 보는 화면 (원하면 바꿔)
    )

    db.commit()
    return

# @router.post("/{request_id}/accept", status_code=status.HTTP_204_NO_CONTENT)
# def accept_exchange_request(
#     request_id: int,
#     body: ExchangeAcceptIn,
#     db: Session = Depends(get_db),
#     current_user: User = Depends(get_current_user),
# ):
#     ex = db.get(ExchangeRequest, request_id)
#     if not ex:
#         raise HTTPException(status_code=404, detail="교환 요청을 찾을 수 없습니다.")

#     if ex.to_user_id != current_user.id:
#         raise HTTPException(status_code=403, detail="이 교환 요청에 대한 권한이 없습니다.")
#     if ex.status != "pending":
#         raise HTTPException(status_code=400, detail="이미 처리된 교환 요청입니다.")

#     # 1) 내 원본 습관 확인 (exchange.target_habit_id 는 Habit 기준)
#     owner_habit = db.get(Habit, ex.target_habit_id)
#     if not owner_habit:
#         raise HTTPException(status_code=404, detail="대상 습관을 찾을 수 없습니다.")

#     # 2) 상대가 예전에 완료했던 UserHabit (바텀시트에서 선택한 것)
#     opponent_uh = db.get(UserHabit, body.opponent_user_habit_id)
#     if not opponent_uh or opponent_uh.user_id != ex.from_user_id:
#         raise HTTPException(status_code=400, detail="상대 완료 습관 정보가 올바르지 않습니다.")

#     # 2-1) 현재 내 해시로 이 난이도의 습관을 감당 가능한지 체크
#     #        (받는 사람은 자기 해시 < 상대 습관 난이도 이면 선택 불가)
#     if opponent_uh.difficulty > current_user.hb_balance:
#         raise HTTPException(
#             status_code=status.HTTP_400_BAD_REQUEST,
#             detail="해시가 부족해서 이 난이도의 습관에는 도전할 수 없습니다.",
#         )
        
#     owner_side_method = opponent_uh.method       # 내가 도전하는 습관 = 상대가 하던 방식
#     challenger_side_method = owner_habit.method
    
#     for m in (owner_side_method, challenger_side_method):
#         if m not in ("photo", "text"):
#             raise HTTPException(
#                 status_code=400,
#                 detail="교환에 사용할 수 없는 인증 방식입니다.",
#             )
            
#     now = datetime.now()
#     stake = ex.difficulty

#     owner_user = db.get(User, ex.to_user_id)
#     challenger_user = db.get(User, ex.from_user_id)
    
#     if owner_user is None or challenger_user is None:
#         raise HTTPException(status_code=400, detail="내기 참가자 정보를 찾을 수 없습니다.")

#     if owner_user.hb_balance < stake:
#         raise HTTPException(
#             status_code=status.HTTP_400_BAD_REQUEST,
#             detail="내 해시가 부족해서 이 난이도로 내기를 시작할 수 없습니다.",
#         )

            
#     # 3) Duel 생성
#     duel = Duel(
#         owner_user_id=ex.to_user_id,
#         challenger_user_id=ex.from_user_id,
#         habit_title=f"{owner_habit.title} vs {opponent_uh.title}",     # 카드에 보여줄 제목을 일단 상대 습관 제목으로 사용
#         method=ex.method,                   # photo/text
#         deadline_local=ex.deadline_local,
#         days_of_week=ex.days_of_week,
#         start_date=ex.start_date,
#         end_date=ex.end_date,
#         difficulty=ex.difficulty,
#         status="active",
#         created_at=now,
#     )
#     db.add(duel)
#     db.flush()  # duel.id 확보

#     owner_user = db.get(User, ex.to_user_id)       # 도전 받은 사람
#     challenger_user = db.get(User, ex.from_user_id)# 도전 건 사람

#     duel_title = duel.habit_title 
#     deeplink = f"/duels/{duel.id}"

#     # 1) 도전 받은 사람에게: "OOO 농부와 내기가 성립되었어요."
#     _create_notification(
#         db=db,
#         user_id=owner_user.id,
#         noti_type="challenge_accepted",
#         title=f"{challenger_user.nickname or challenger_user.name} 농부와 내기가 시작되었어요.",
#         body=duel_title,
#         deeplink=deeplink,
#     )
    
#     # 2) 도전 건 사람에게도 같은 취지 알림
#     _create_notification(
#         db=db,
#         user_id=challenger_user.id,
#         noti_type="challenge_accepted",
#         title=f"{owner_user.nickname or owner_user.name} 농부와 내기가 시작되었어요.",
#         body=duel_title,
#         deeplink=deeplink,
#     )
#     # 4) Duel용 UserHabit 두 개 생성

#     # 4-1) 나(도전 받은 사람)는 상대 완료 습관(opponent_uh)에 도전
#     owner_duel_habit = UserHabit(
#         user_id=ex.to_user_id,                
#         source_habit_id=opponent_uh.source_habit_id,
#         title=opponent_uh.title,
#         method=opponent_uh.method,
#         deadline_local=ex.deadline_local,
#         days_of_week=ex.days_of_week,
#         period_start=ex.start_date,
#         period_end=ex.end_date,
#         is_active=True,
#         created_at=now,
#         difficulty=ex.difficulty,
#         status="active",
#         duel_id=duel.id,
#     )

#     # 4-2) 상대(도전 건 사람)는 내 원본(owner_habit)에 도전
#     challenger_duel_habit = UserHabit(
#         user_id=ex.from_user_id,          # 송강호
#         source_habit_id=owner_habit.id,   # 코테
#         title=owner_habit.title,
#         method=owner_habit.method,
#         deadline_local=ex.deadline_local,
#         days_of_week=ex.days_of_week,
#         period_start=ex.start_date,
#         period_end=ex.end_date,
#         is_active=True,
#         created_at=now,
#         difficulty=ex.difficulty,
#         status="active",
#         duel_id=duel.id,
#     )

#     db.add_all([owner_duel_habit, challenger_duel_habit])

#     owner_user.hb_balance -= stake
    
#     # 5) 교환 요청 삭제
#     db.delete(ex)

#     db.commit()
#     return

