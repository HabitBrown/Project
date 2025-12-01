from __future__ import annotations
from sqlalchemy.orm import declarative_base
from ..database import engine

Base = declarative_base()

def create_all():
    # 모든 모델 import
    from . import user, habit, user_habit, exchange, duel, media,attendance_log
    from . import certification, dispute, wallet, notification, badge, shop
    Base.metadata.create_all(bind=engine)
