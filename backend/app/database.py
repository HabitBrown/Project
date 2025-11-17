from __future__ import annotations
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker,Session

# MySQL 연결 URL
# 예: mysql+pymysql://root:password@localhost:3306/hashbrown?charset=utf8mb4
DB_URL = os.getenv(
    "HASHBROWN_DB_URL",
    "mysql+pymysql://root:kangho6716!@localhost:3306/hashbrown?charset=utf8mb4"
)

engine = create_engine(
    DB_URL,
    pool_pre_ping=True,
    pool_recycle=3600,
    echo=False,
    future=True,
)

SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)

def get_db() -> Session:
    """
    FastAPI 의존성 주입용 DB 세션 생성기
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()