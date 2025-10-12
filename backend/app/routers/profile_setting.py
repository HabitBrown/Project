from backend.app.database import SessionLocal
from backend.app.models.user import User
from sqlalchemy import update

class Profile(object):
    def __init__(self, phone: int, profile_picture: str):
        self._phone = phone
        self._profile_picture = profile_picture

    def update_profile(self):
        update_user = (
            update(User)
            .where(User.phone == self._phone)
            .values(
                profile_picture=self._profile_picture,
            )
        )
        SessionLocal.execute(update_user)
        SessionLocal.commit()