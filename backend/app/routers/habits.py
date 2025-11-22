# app/routers/habits.py
from typing import List, Optional
from datetime import datetime, date, timedelta, timezone

from fastapi import APIRouter, Depends, Query, HTTPException, status
from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.models.user import User
from app.models.user_habit import UserHabit
from app.models.habit import Habit
from app.models.certification import Certification 
from app.schemas.habit import HabitSearchItemOut, HabitCreateIn, CompletedHabitItemOut
from app.routers.register import get_current_user

router = APIRouter(prefix="/habits", tags=["Habits"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def _iter_scheduled_dates(user_habit: UserHabit):
    """
    이 UserHabit이 실제로 인증해야 하는 '날짜들'을 모두 생성해주는 제너레이터.
    days_of_week는 1~7(월~일) 비트마스크라고 가정.
    """
    if not user_habit.period_start or not user_habit.period_end:
        return

    mask = user_habit.days_of_week or 0
    cur = user_habit.period_start
    last = user_habit.period_end

    # SQLAlchemy Date → Python date 라고 가정
    while cur <= last:
        # isoweekday(): 월=1, ..., 일=7
        w = cur.isoweekday()
        if mask & (1 << (w - 1)):
            yield cur
        cur += timedelta(days=1)

def _evaluate_single_habit(db: Session, habit: UserHabit, now_utc: datetime, success_ratio: float = 0.7):
    """
    하나의 UserHabit에 대해, 도전 기간이 끝났다면
    인증 성공률을 계산해서 completed_success / completed_fail 로 바꿔준다.
    """

    # 이미 끝난 습관은 건드리지 않음
    if habit.status != "active":
        return

    if habit.period_end is None or habit.period_start is None:
        return

    # 한국 시간 기준 오늘 > period_end 일 때만 평가
    KST = timezone(timedelta(hours=9))
    now_kst = now_utc.astimezone(KST)

    if now_kst.date() <= habit.period_end:
        # 아직 도전 기간이 안 끝났음
        return

    # 1) 원래 인증해야 하는 날짜 목록
    scheduled_dates = list(_iter_scheduled_dates(habit))

    if not scheduled_dates:
        # 인증해야 할 날이 없다면 실패로 처리 (혹은 그냥 무시도 가능)
        habit.status = "completed_fail"
        habit.completed_at = now_utc
        return

    # 2) 해당 기간 동안의 성공 인증 가져오기
    #    (KST 기준 날짜 범위를 UTC로 변환해서 조회)
    first_day = scheduled_dates[0]
    last_day = scheduled_dates[-1]

    start_kst = datetime(first_day.year, first_day.month, first_day.day, tzinfo=KST)
    end_kst = datetime(last_day.year, last_day.month, last_day.day, tzinfo=KST) + timedelta(days=1)

    start_utc = start_kst.astimezone(timezone.utc)
    end_utc = end_kst.astimezone(timezone.utc)

    certs = (
        db.query(Certification)
        .filter(
            Certification.user_id == habit.user_id,
            Certification.user_habit_id == habit.id,
            Certification.status == "success",
            Certification.ts_utc >= start_utc,
            Certification.ts_utc < end_utc,
        )
        .all()
    )

    # 성공한 '날짜'만 추려서 집합으로 (중복 인증 방지)
    success_dates = set()
    for c in certs:
        d = c.ts_utc.astimezone(KST).date()
        success_dates.add(d)

    # 3) 실제로 잘 지킨 날: 원래 인증해야 하는 날 중, success_dates에 포함된 날짜
    total_slots = len(scheduled_dates)
    done_slots = sum(1 for d in scheduled_dates if d in success_dates)

    ratio = done_slots / total_slots if total_slots > 0 else 0.0

    if ratio >= success_ratio and done_slots > 0:
        habit.status = "completed_success"
    else:
        habit.status = "completed_fail"

    habit.completed_at = now_utc

@router.post("", response_model=HabitSearchItemOut)
def create_habit(
    body: HabitCreateIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
 
    # 1) source_habit_id 처리
    source_habit_id = body.source_habit_id

    if source_habit_id is not None:
        # 다른 사람 습관(템플릿)을 복사하는 경우
        source_habit = db.query(Habit).filter(Habit.id == source_habit_id).first()
        if not source_habit:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="source_habit_id에 해당하는 습관 템플릿이 없습니다.",
            )
    else:
        # 내가 처음으로 새 습관을 만드는 경우 → Habit(템플릿)부터 생성
        new_habit_template = Habit(
            owner_user_id=current_user.id,
            title=body.title,
            description=None,
            created_at=datetime.utcnow(),
        )
        db.add(new_habit_template)
        db.flush()  # new_habit_template.id 확보
        source_habit_id = new_habit_template.id

    # 2) UserHabit 생성
    new_user_habit = UserHabit(
        user_id=current_user.id,
        source_habit_id=source_habit_id,
        title=body.title,
        method=body.method,
        days_of_week=body.days_of_week,
        period_start=body.period_start,
        period_end=body.period_end,
        deadline_local=body.deadline_local,
        difficulty=body.difficulty,
        created_at=datetime.utcnow(),
    )

    db.add(new_user_habit)
    db.commit()
    db.refresh(new_user_habit)

    # 3) 응답: 검색용 DTO 포맷 재사용
    return HabitSearchItemOut(
        user_habit_id=new_user_habit.id,
        owner_id=current_user.id,
        owner_nickname=current_user.nickname,
        title=new_user_habit.title,
        method=new_user_habit.method,
        difficulty=new_user_habit.difficulty,
        period_start=new_user_habit.period_start,
        period_end=new_user_habit.period_end,
        deadline_local=new_user_habit.deadline_local,
    )

@router.put("/{user_habit_id}", response_model=HabitSearchItemOut)
def update_habit(
    user_habit_id: int,
    body: HabitCreateIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    내가 만든 습관(UserHabit) 수정하기

    - path param: user_habit_id (UserHabit.id)
    - body: HabitCreateIn (생성할 때 쓰던 구조 재사용)
    - 내 습관만 수정 가능
    - 이미 완료된 습관(status가 completed_* 인 경우)은 수정 불가
    """

    # 1) 수정 대상 UserHabit 조회 (내 것만)
    user_habit = (
        db.query(UserHabit)
        .filter(
            UserHabit.id == user_habit_id,
            UserHabit.user_id == current_user.id,
        )
        .first()
    )

    if not user_habit:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="해당 ID의 습관을 찾을 수 없거나, 내 습관이 아닙니다.",
        )

    # 2) 완료된 습관은 수정 불가
    if user_habit.status in ["completed_success", "completed_fail"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="이미 완료된 습관은 수정할 수 없습니다.",
        )

    # 3) 필드 수정 (생성과 동일한 필드들)
    user_habit.title         = body.title
    user_habit.method        = body.method
    user_habit.days_of_week  = body.days_of_week
    user_habit.period_start  = body.period_start
    user_habit.period_end    = body.period_end
    user_habit.deadline_local = body.deadline_local
    user_habit.difficulty    = body.difficulty

    # 필요하다면 updated_at 컬럼이 있다면 여기서 갱신
    # user_habit.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(user_habit)

    # 4) 응답 DTO (생성 때와 동일한 포맷)
    return HabitSearchItemOut(
        user_habit_id=user_habit.id,
        owner_id=current_user.id,
        owner_nickname=current_user.nickname,
        title=user_habit.title,
        method=user_habit.method,
        difficulty=user_habit.difficulty,
        period_start=user_habit.period_start,
        period_end=user_habit.period_end,
        deadline_local=user_habit.deadline_local,
    )

@router.get("/search", response_model=List[HabitSearchItemOut])
def search_habits(
    q: Optional[str] = Query(None, description="검색어(습관 제목)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    다른 사람들의 활성 습관 검색.
    - 내 습관은 기본적으로 제외
    - 난이도(difficulty) 포함해서 내려줌
    """

    query = (
        db.query(UserHabit, User)
        .join(User, UserHabit.user_id == User.id)
        .filter(
            UserHabit.is_active == True,
            UserHabit.duel_id.is_(None),          # 기본적으로 '혼자 습관' 검색
            UserHabit.user_id != current_user.id  # 내 습관 제외
        )
    )

    if q:
        query = query.filter(UserHabit.title.contains(q))

    rows = query.all()

    results: List[HabitSearchItemOut] = []
    for user_habit, owner in rows:
        results.append(
            HabitSearchItemOut(
                user_habit_id=user_habit.id,
                owner_id=owner.id,
                owner_nickname=owner.nickname,
                title=user_habit.title,
                method=user_habit.method,
                difficulty=user_habit.difficulty,
                period_start=user_habit.period_start,
                period_end=user_habit.period_end,
                deadline_local=user_habit.deadline_local,
            )
        )

    return results

@router.get("/me/completed", response_model=List[CompletedHabitItemOut])
def get_my_completed_habits(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    마이페이지 - 완료된 습관 리스트 조회

    전제:
    - UserHabit.status 가 'completed_success' 또는 'completed_fail' 일 때 "완료된 습관"으로 본다.
      (Enum 값은 네가 실제로 정의한 값에 맞게 수정)
    """

    query = (
        db.query(UserHabit)
        .filter(
            UserHabit.user_id == current_user.id,
            UserHabit.status.in_(["completed_success"]),
        )
        .order_by(UserHabit.completed_at.desc())
    )

    rows = query.all()

    results: List[CompletedHabitItemOut] = []
    for uh in rows:
        results.append(
            CompletedHabitItemOut(
                user_habit_id=uh.id,
                title=uh.title,
                method=uh.method,
                difficulty=uh.difficulty,
                period_start=uh.period_start,
                period_end=uh.period_end,
                status=uh.status,              # Enum → str
                completed_at=uh.completed_at,
            )
        )

    return results

@router.post("/evaluate", summary="기간이 끝난 내 습관들을 성공/실패로 정산")
def evaluate_my_habits(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    - status = 'active' 이고
    - period_end 가 지난 습관들에 대해
      성공/실패를 판정해서 status와 completed_at을 갱신한다.
    """
    now_utc = datetime.now(timezone.utc)

    # 아직 active 상태인 내 습관들만
    habits = (
        db.query(UserHabit)
        .filter(
            UserHabit.user_id == current_user.id,
            UserHabit.status == "active",
            UserHabit.period_end != None,
        )
        .all()
    )

    success_count = 0
    fail_count = 0

    for h in habits:
        before = h.status
        _evaluate_single_habit(db, h, now_utc)
        after = h.status

        if before != after:
            if after == "completed_success":
                success_count += 1
            elif after == "completed_fail":
                fail_count += 1

    db.commit()

    return {
        "evaluated": len(habits),
        "success_updated": success_count,
        "fail_updated": fail_count,
    }
