from typing import Optional
from sqlalchemy.exc import IntegrityError
from backend.app.database import SessionLocal
from backend.app.models.user_habit import UserHabit
from datetime import datetime, date, time

class Habit(object):
    def __init__(self, uid: int, habit_id: Optional[int], title: str, method: str, deadline: time, days_of_week: int, period_start: date, period_end: date, is_active: bool):
        self._uid = uid
        self._habit_id = habit_id
        self._title = title
        self._method = method
        self._deadline = deadline
        self._days_of_week = days_of_week
        self._period_start = period_start
        self._period_end = period_end
        self._is_active = is_active or True

        # 생성일은 자동으로 처리
        self.created_at = datetime.now().strftime("%Y%m%d")

    def setting_habit(self):
        user_habit = UserHabit(
            user_id = self._uid,
            source_habit_id = self._habit_id,
            title = self._title,
            method = self._method,
            deadline = self._deadline,
            days_of_week = self._days_of_week,
            period_start = self._period_start,
            period_end = self._period_end,
            is_active = self._is_active,
            created_at = self.created_at
        )

        with SessionLocal() as db:
            db.add(user_habit)
            try:
                db.commit()
            except IntegrityError as e:
                db.rollback()
                raise ValueError("에러") from e
            db.refresh(user_habit)
            return user_habit