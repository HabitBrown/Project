# app/routers/habits.py
from typing import List, Optional
from datetime import datetime

from fastapi import APIRouter, Depends, Query, HTTPException, status
from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.models.user import User
from app.models.user_habit import UserHabit
from app.models.habit import Habit
from app.schemas.habit import HabitSearchItemOut, HabitCreateIn, CompletedHabitItemOut
from app.routers.register import get_current_user

router = APIRouter(prefix="/habits", tags=["Habits"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()



@router.post("", response_model=HabitSearchItemOut)
def create_habit(
    body: HabitCreateIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    혼자 습관 등록 API

    설계 의도:
    - Habit : 습관 템플릿 (공유/복사 기준)
    - UserHabit : 실제 유저가 수행하는 습관 인스턴스

    동작:
    - body.source_habit_id 가 없으면
        -> 새 Habit(템플릿)을 만들고
        -> 그 Habit.id 를 참조하는 UserHabit 생성
    - body.source_habit_id 가 있으면
        -> 해당 Habit 이 존재하는지 확인하고
        -> 그 Habit 을 참조하는 UserHabit만 생성
    """

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
            UserHabit.status.in_(["completed_success", "completed_fail"]),
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