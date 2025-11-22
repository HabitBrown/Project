from datetime import datetime, timezone
from uuid import uuid4
import os

from fastapi import APIRouter, Depends, File, UploadFile, HTTPException, status
from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.models.user import User
from app.models.media import MediaAsset
from app.schemas.media import MediaAssetOut
from app.routers.register import get_current_user

from fastapi.staticfiles import StaticFiles

router = APIRouter(prefix="/media", tags=["Media"])

UPLOAD_DIR = "uploads"  # 실제 경로는 프로젝트에 맞게 조정

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.post("/upload", response_model=MediaAssetOut, status_code=status.HTTP_201_CREATED)
async def upload_media(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # 1) 파일 저장 경로 만들기
    os.makedirs(UPLOAD_DIR, exist_ok=True)
    ext = os.path.splitext(file.filename)[1]
    filename = f"{uuid4().hex}{ext}"
    path = os.path.join(UPLOAD_DIR, filename)

    # 2) 디스크에 저장
    contents = await file.read()
    with open(path, "wb") as f:
        f.write(contents)

    # 3) DB에 MediaAsset 생성
    asset = MediaAsset(
        uploader_id=current_user.id,
        storage_url= f"/uploads/{filename}",      # 나중에 Nginx/정적 파일 설정과 맞추면 됨
        exif_taken_at=None,
        sha256=None,
        created_at=datetime.now(timezone.utc),
    )
    db.add(asset)
    db.commit()
    db.refresh(asset)

    return asset
