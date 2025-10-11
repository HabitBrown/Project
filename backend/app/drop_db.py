from app.database import engine
from app.models import user  # 다른 모델도 import 필요
from sqlalchemy.orm import declarative_base

Base = user.Base  # 모든 모델들이 공통 Base를 상속한다고 가정

print("⚠️ 모든 테이블을 삭제합니다...")
Base.metadata.drop_all(bind=engine)
print("✅ 삭제 완료")
