from datetime import datetime, date, time
from sqlalchemy.exc import IntegrityError
from backend.app.database import SessionLocal
from backend.app.models.duel import Duel

class SettingDuel(object):
    # Duel의 구조와 다르게 status, result는 default 값이 없기에 앞으로 당겼습니다.
    def __init__(self,
                 owner_user_id: int,
                 challenger_user_id: int,
                 habit_title: str,
                 method: str,
                 deadline_local: time,
                 days_of_week: int,
                 start_date: date,
                 end_date: date,
                 status,
                 result,
                 difficulty: int = 1,
                 owner_success_cnt: int = 0,
                 challenger_success_cnt: int = 0,
                 grace_minutes: int = 5
                 ):
        self.owner_user_id = owner_user_id
        self.challenger_user_id = challenger_user_id
        self.habit_title = habit_title
        self.method = method
        self.deadline_local = deadline_local
        self.days_of_week = days_of_week
        self.start_date = start_date
        self.end_date = end_date
        self.status = status
        self.result = result
        self.difficulty = difficulty
        self.owner_success_cnt = owner_success_cnt
        self.challenger_success_cnt = challenger_success_cnt
        self.grace_minutes = grace_minutes

        self.created_at = datetime.now().strftime("%Y%m%d")

    def insert_duel(self):
        duel = Duel(
            owner_user_id=self.owner_user_id,
            challenger_user_id=self.challenger_user_id,
            habit_title=self.habit_title,
            method=self.method,
            deadline_local=self.deadline_local,
            days_of_week=self.days_of_week,
            start_date=self.start_date,
            end_date=self.end_date,
            status=self.status,
            result=self.result,
            difficulty=self.difficulty,
            owner_success_cnt=self.owner_success_cnt,
            challenger_success_cnt=self.challenger_success_cnt,
            grace_minutes=self.grace_minutes
        )

        with SessionLocal() as db:
            db.add(duel)
            try:
                db.commit()
            except IntegrityError as e:
                db.rollback()
                raise ValueError("에러") from e
            db.refresh(duel)
            return duel