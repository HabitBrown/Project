# app/routers/home.py
from datetime import datetime, date, time

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import or_

from app.database import SessionLocal
from app.models.user import User
from app.models.user_habit import UserHabit
from app.models.duel import Duel
from app.models.certification import Certification
from app.schemas.home import HomeSummaryOut, HomeHabitItemOut

from app.routers.register import get_current_user

router = APIRouter(prefix="/home", tags=["Home"])


# DB 세션 의존성
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.get("/summary", response_model=HomeSummaryOut)
def get_home_summary(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    홈 화면 요약 정보 + 오늘 습관 리스트

    - today_cert_count: 오늘 인증 성공 횟수
    - current_duel_count: 오늘 기준 진행 중인 결투 개수
    - solo_habit_count: 혼자 하는(active) 습관 개수
    - today_habits: 오늘 해야 하는 '혼자 습관' 목록
    - fighting_habits: 오늘 기준 진행 중인 '듀얼 습관' 목록
    """

    # 1) 오늘 날짜 (UTC 기준) - 나중에 타임존 로직 필요하면 교체
    today: date = datetime.utcnow().date()

    # 하루 시작/끝 (UTC 기준)
    start_utc = datetime.combine(today, time(0, 0, 0))
    end_utc = datetime.combine(today, time(23, 59, 59))

    # 2) 오늘 인증 수 (success)
    today_cert_count = (
        db.query(Certification)
        .filter(
            Certification.user_id == current_user.id,
            Certification.status == "success",
            Certification.ts_utc >= start_utc,
            Certification.ts_utc <= end_utc,
        )
        .count()
    )

    # 3) 현재 진행 중인 결투 수
    current_duel_count = (
        db.query(Duel)
        .filter(
            Duel.status == "active",
            Duel.start_date <= today,
            Duel.end_date >= today,
            or_(
                Duel.owner_user_id == current_user.id,
                Duel.challenger_user_id == current_user.id,
            ),
        )
        .count()
    )

    # 4) 혼자 습관 수 (듀얼에 속하지 않은, 활성 습관 전체 개수)
    solo_q = (
        db.query(UserHabit)
        .filter(
            UserHabit.user_id == current_user.id,
            UserHabit.is_active == True,
            UserHabit.duel_id.is_(None),
        )
    )
    solo_habit_count = solo_q.count()

    # ==========================================
    # 5) 오늘 해야 하는 "혼자" 습관 목록 ( _seedToday 대응 )
    # ==========================================

    # 요일 비트마스크 계산: 월=0 ~ 일=6
    dow = today.weekday()
    mask = 1 << dow

    solo_today = (
        solo_q.filter(
            UserHabit.period_start <= today,
            UserHabit.period_end >= today,
            # days_of_week 비트마스크에 오늘 요일이 포함된 것만
            (UserHabit.days_of_week.op("&")(mask)) != 0,
        )
        .all()
    )

    today_habits: list[HomeHabitItemOut] = [
        HomeHabitItemOut(
            user_habit_id=h.id,
            title=h.title,
            method=h.method,           # "photo" / "text"
            deadline_local=h.deadline_local,
            progress=0.0,              # 나중에 인증 비율 계산해서 넣어도 됨
        )
        for h in solo_today
    ]

    # ==========================================
    # 6) 오늘 기준 진행 중인 "듀얼" 습관 목록 ( _seedFighting 대응 )
    # ==========================================

    duel_rows = (
        db.query(UserHabit, Duel)
        .join(Duel, UserHabit.duel_id == Duel.id)
        .filter(
            UserHabit.user_id == current_user.id,
            UserHabit.is_active == True,
            Duel.status == "active",
            Duel.start_date <= today,
            Duel.end_date >= today,
            or_(
                Duel.owner_user_id == current_user.id,
                Duel.challenger_user_id == current_user.id,
            ),
            # 듀얼 요일 비트마스크로 오늘 포함 여부 체크
            (Duel.days_of_week.op("&")(mask)) != 0,
        )
        .all()
    )

    fighting_habits: list[HomeHabitItemOut] = [
        HomeHabitItemOut(
            user_habit_id=uh.id,
            # 타이틀은 유저 습관 제목을 기준으로 사용 (필요하면 duel.habit_title로 변경 가능)
            title=uh.title,
            method=uh.method,
            deadline_local=uh.deadline_local,
            progress=0.0,
        )
        for uh, duel in duel_rows
    ]

    # 최종 응답
    return HomeSummaryOut(
        today_cert_count=today_cert_count,
        current_duel_count=current_duel_count,
        solo_habit_count=solo_habit_count,
        today_habits=today_habits,
        fighting_habits=fighting_habits,
    )
