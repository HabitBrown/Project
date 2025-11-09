from __future__ import annotations
import os, uuid, hashlib
from pathlib import Path
from fastapi import UploadFile, HTTPException

# 환경변수로 업로드 루트 지정 가능 (기본값: ./uploads)
UPLOAD_ROOT = Path(os.getenv("HASHBROWN_UPLOAD_ROOT", "uploads")).resolve()

ALLOWED_IMAGE_TYPES = {"image/png", "image/jpeg", "image/jpg", "image/webp"}

def ensure_dirs(subdir: str) -> Path:
    target = UPLOAD_ROOT / subdir
    target.mkdir(parents=True, exist_ok=True)
    return target

async def save_image(file: UploadFile, subdir: str = "profile") -> tuple[str, str]:
    if file.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(status_code=400, detail="지원하지 않는 이미지 형식입니다.")

    folder = ensure_dirs(subdir)
    ext = {
        "image/png": "png",
        "image/jpeg": "jpg",
        "image/jpg": "jpg",
        "image/webp": "webp",
    }[file.content_type]

    # 파일명 충돌 방지
    fname = f"{uuid.uuid4().hex}.{ext}"
    fpath = folder / fname

    # 스트리밍 저장 + SHA256 해시 계산
    hasher = hashlib.sha256()
    with fpath.open("wb") as out:
        while True:
            chunk = await file.read(1024 * 1024)
            if not chunk:
                break
            hasher.update(chunk)
            out.write(chunk)

    sha256 = hasher.hexdigest()
    # 정적 서빙 기준의 상대 URL 생성
    public_url = f"/uploads/{subdir}/{fname}"
    return public_url, sha256