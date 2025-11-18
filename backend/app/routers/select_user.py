from datetime import datetime, date, time
from sqlalchemy.exc import IntegrityError
from backend.app.database import SessionLocal
from backend.app.models.user import User, UserInterest, Interest, Follow
from backend.app.models.habit import Habit
from sqlalchemy import select, update

class UserInfo(object):
    def __init__(self, phone: str):
        self.phone = phone

    def select_user(self):
        session = SessionLocal()

        select_user = select(User).where(User.phone == self.phone)
        res_user = session.execute(select_user)
        user = res_user.scalars().first()

        if user:
            # 관심사 (UserInterest)
            select_inter = select(UserInterest).where(UserInterest.id == user.id)
            res_inter = session.execute(select_inter)
            interest = res_inter.scalars().all()

            # 관심사 이름만 가져오기
            interest_list = []
            for inter in interest:
                each_select_inter = select(Interest).where(Interest.id == inter.interest_id)
                each_res_inter = session.execute(each_select_inter)
                each_interest = each_res_inter.scalars().first()
                interest_list.append(each_interest)

            select_habit = select(Habit).where(Habit.owner_user_id == user.id)
            res_habit = session.execute(select_habit)
            habit = res_habit.scalars().all()

            # 만든 습관 이름만 가져오기
            habit_list = [each_habit.title for each_habit in habit]

            # 유저 닉네임, 유저 자기소개 (레벨은 안보여서 안넣었어요)
            data = [user.nickname, user.bio]

            # 관심사

    def follow_user(self, follower_id: int):
        session = SessionLocal()

        select_user = select(User).where(User.phone == self.phone)
        res_user = session.execute(select_user)
        user = res_user.scalars().first()

        if user:
            uid = user.id
            follow = Follow(follower_id=follower_id, followee_id=uid)

            with SessionLocal() as db:
                db.add(follow)
                try:
                    db.commit()
                except IntegrityError as e:
                    db.rollback()
                    raise ValueError("에러") from e
                db.refresh(follow)
                return