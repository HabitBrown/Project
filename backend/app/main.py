from __future__ import annotations

import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from app.scheduler import start_scheduler

from app.routers import (
    register,auth,
    profile_setting,
    home,habits,
    user_interest,
    potato,exchange,
    certification,media,
    duel,attendance,
    notification)

app = FastAPI(title="Hashbrown API", version="1.0.0")
start_scheduler()

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
app.include_router(home.router)
app.include_router(habits.router)
app.include_router(user_interest.router)
app.include_router(potato.router)
app.include_router(exchange.router)
app.include_router(certification.router)
app.include_router(media.router)
app.include_router(duel.router)
app.include_router(attendance.router)
app.include_router(notification.router)
@app.get("/health")
def health():
    return {"status": "ok"}
