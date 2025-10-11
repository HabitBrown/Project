# app/utils/nickname.py
import re
import random
from sqlalchemy.orm import Session
from app.models.user import User

def _slugify(base: str) -> str:
    base = base.strip().lower()
    base = re.sub(r"\s+", "_", base)
    base = re.sub(r"[^a-z0-9_]", "", base)
    return base or "user"

def generate_unique_nickname(db: Session, base: str) -> str:
    seed = _slugify(base)
    cand = seed
    # 동일 닉네임이 없으면 그대로 사용, 있으면 숫자 붙여 중복 회피
    i = 0
    while True:
        exists = db.query(User).filter(User.nickname == cand).first()
        if not exists:
            return cand
        i += 1
        # i가 커지면 난수 섞어서 충돌 줄이기
        if i < 20:
            cand = f"{seed}{i}"
        else:
            cand = f"{seed}{random.randint(1000, 9999)}"
