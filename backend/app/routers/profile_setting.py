from backend.app.database import SessionLocal
from backend.app.models.user import User
from sqlalchemy import select

class Profile(object):
    def __init__(self, phone: int, profile_picture: str):
        self._phone = phone
        self._profile_picture = profile_picture

    def update_profile(self):
        session = SessionLocal()

        select_user = select(User).where(User.phone == self._phone)
        res_user = session.execute(select_user)
        user = res_user.scalars().first()

        if user:
            user.profile_picture = self._profile_picture
            session.commit()

        return