from __future__ import annotations

import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.routers import register, auth
from app.routers import profile_setting  # ⬅️ 프로필 라우터 추가

app = FastAPI(title="Hashbrown API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # 배포 시 도메인으로 제한 권장
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 업로드 폴더 정적 서빙 (/uploads/**)
uploads_dir = Path(os.getenv("HASHBROWN_UPLOAD_ROOT", "uploads")).resolve()
uploads_dir.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=str(uploads_dir)), name="uploads")

# 라우터 등록
app.include_router(register.router)
app.include_router(auth.router)
app.include_router(profile_setting.router)  

@app.get("/health")
def health():
    return {"status": "ok"}
