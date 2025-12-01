# app/drop_db.py

from app.database import engine
from app.models.base import Base  # 공통 Base 가져오기
from sqlalchemy import text

# ⚠️ 모든 모델 import 해서 Base.metadata에 등록
from app.models import (
    user,
    attendance_log,
    badge,
    certification,
    dispute,
    duel,
    exchange,
    habit,
    media,
    notification,
    shop,
    user_habit,
    wallet,
)

def drop_all_tables() -> None:
    print("⚠️ 모든 테이블을 삭제합니다... (FOREIGN_KEY_CHECKS=0)")

    # MySQL 외래키 체크 잠깐 끄고 전체 드롭
    with engine.connect() as conn:
        # FK 체크 비활성화
        conn.execute(text("SET FOREIGN_KEY_CHECKS = 0"))

        # SQLAlchemy 메타데이터 기준으로 전부 DROP
        Base.metadata.drop_all(bind=conn)

        # FK 체크 다시 활성화
        conn.execute(text("SET FOREIGN_KEY_CHECKS = 1"))

    print("✅ 삭제 완료")

if __name__ == "__main__":
    drop_all_tables()
