# app/routers/attendance.py
from datetime import datetime, timedelta, date, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select

from app.database import SessionLocal
from app.models.user import User
from app.models.attendance_log import AttendanceLog
from app.routers.register import get_current_user  # 이미 쓰는 인증 의존성

router = APIRouter(prefix="/attendance", tags=["Attendance"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def _today_local() -> date:
    # 서버를 Asia/Seoul 기준이라고 가정 (더 정교하게 하려면 user.timezone 사용)
    now = datetime.now()   
    return date(year=now.year, month=now.month, day=now.day)


@router.post("/check-in")
def check_in_attendance(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    ):
    """
    출석 체크 API   
    - 매일 최초 출석 시: 기본 +1 해시 지급
    - 7일째 출석 날: 기본 +1 + 보너스 +5 = 총 +6
    - 하루에 한 번만 출석 가능
    - streak는 1~7까지만 돌고, 7일 달성 후 다음날은 다시 1일부터 시작
    """
    today = _today_local()  
    
    db_user = db.get(User, current_user.id)
    if db_user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
        
    # 1) 오늘 이미 출석했는지 확인
    existing_today = db.scalar(
      select(AttendanceLog).where(
        AttendanceLog.user_id == db_user.id,
        AttendanceLog.attend_date == today,
      )
    )

    if existing_today:
    # 이미 출석한 날이면 추가 보상 없음
        return {
            "already_checked": True,
            "today_reward": 0,
            "streak": existing_today.streak,
            "hb_balance": db_user.hb_balance or 0,
            "today": str(today),
            "is_seven_day_reward": existing_today.streak == 7,
        }

  # 2) 가장 최근 출석 기록 가져오기 (어제인지, 끊겼는지 확인용)
    last_log = db.scalar(
        select(AttendanceLog)
        .where(AttendanceLog.user_id == db_user.id)
        .order_by(AttendanceLog.attend_date.desc())
        .limit(1)
        )

    new_streak = 1
    if last_log is not None:
        last_date = last_log.attend_date
        # 어제였다면 → streak + 1
        if today == last_date + timedelta(days=1) and last_log.streak < 7:
            new_streak = last_log.streak + 1
        else:
        # 어제가 아니거나, 이미 7이었으면 → 다시 1일부터
            new_streak = 1

    # 3) 오늘 보상 계산
    base_reward = 1
    bonus_reward = 5 if new_streak == 7 else 0
    today_reward = base_reward + bonus_reward

    # 4) User 해시 재화 업데이트
    db_user.hb_balance = (db_user.hb_balance or 0) + today_reward

    # 5) AttendanceLog 저장
    log = AttendanceLog(
        user_id=db_user.id,
        attend_date=today,
        streak=new_streak,
        reward=today_reward,
    )
    db.add(log)

    db.commit()
    db.refresh(db_user)
    db.refresh(log)

    return {
      "already_checked": False,
      "today_reward": today_reward,
      "streak": new_streak,
      "hb_balance": db_user.hb_balance,
      "today": str(today),
      "is_seven_day_reward": new_streak == 7,
    }
