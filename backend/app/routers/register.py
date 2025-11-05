import hashlib
import datetime
from typing import Optional
from sqlalchemy.exc import IntegrityError
from backend.app.database import SessionLocal
from backend.app.models.user import User

class Register(object):
    # 회원가입 시 사용하는 유저의 정보
    def __init__(self, phone: str, password: str, nickname: str, gender: Optional[str] = None, age: Optional[int] = None, timezone: Optional[str] = None):
        self._phone = phone
        self._password = hashlib.sha256((password + phone).encode()).hexdigest()
        self._nickname = nickname
        self._gender = gender
        self._age = age
        self._bio = 'none'
        self._profile_picture = 'none'

        # 시작 금액은 0이므로 (가변가능)
        self._hb_balance = 0

        # created_at은 어디를 기준으로 할 지 논의가 필요
        self._created_at = datetime.datetime.now()
        self._timezone = timezone or "Asia/Seoul"

    def register_user(self):
        user = User(
            phone=self._phone,
            password_hash=self._password,
            nickname=self._nickname,
            gender=self._gender,
            age=self._age,
            bio=self._bio,
            profile_picture=self._profile_picture,
            timezone=self._timezone,
            hb_balance=self._hb_balance,
            created_at=self._created_at,
        )

        with SessionLocal() as db:
            db.add(user)
            try:
                db.commit()
            except IntegrityError as e:
                db.rollback()
                raise ValueError("에러") from e
            db.refresh(user)
            return user