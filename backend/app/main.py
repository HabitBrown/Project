from fastapi import FastAPI
from app.routers import register, auth 
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Hashbrown API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 배포 시 도메인으로 제한 권장
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# /auth/register, /auth/login
app.include_router(register.router)
app.include_router(auth.router)

@app.get("/health")
def health():
    return {"status": "ok"}
