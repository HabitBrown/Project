import os
import datetime
import hashlib
from typing import Optional, Dict, Any

from fastapi import APIRouter, Depends, HTTPException, status, Path, Query
from sqlalchemy.orm import Session
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from jose import jwt

from app.database import SessionLocal
from app.models.user import User
from app.schemas.auth import RegisterIn, LoginIn, UserOut, TokenOut, UpdateUserIn

router = APIRouter(prefix="/auth", tags=["Auth"])


# -----------------------------
# 내부 클래스
# -----------------------------
class Register:
    """회원가입 시 사용하는 유저 정보 처리"""

    def __init__(
        self,
        phone: str,
        password: str,
        name: str,
        gender: Optional[str] = None,
        age: Optional[int] = None,
        timezone: Optional[str] = None,
    ):
        self._phone = phone
        self._password = hashlib.sha256((password + phone).encode()).hexdigest()
        self._name = name
        self._nickname = None  # ✅ 닉네임은 profile_setup 단계에서 등록
        self._gender = gender or "N"
        self._age = age
        self._bio = "none"
        self._profile_picture = "none"
        self._hb_balance = 0
        self._created_at = datetime.datetime.now(datetime.timezone.utc)
        self._timezone = timezone or "Asia/Seoul"

    def register_user(self, db: Optional[Session] = None):
        should_close = False
        if db is None:
            db = SessionLocal()
            should_close = True
        try:
            user = User(
                phone=self._phone,
                password_hash=self._password,
                name=self._name,
                nickname=self._nickname,
                gender=self._gender,
                age=self._age,
                bio=self._bio,
                profile_picture=self._profile_picture,
                timezone=self._timezone,
                hb_balance=self._hb_balance,
                created_at=self._created_at,
            )
            db.add(user)
            db.commit()
            db.refresh(user)
            return user
        except IntegrityError as e:
            db.rollback()
            raise ValueError("회원가입 중 중복된 전화번호가 있습니다.") from e
        except Exception as e:
            db.rollback()
            raise ValueError("회원가입 중 오류가 발생했습니다.") from e
        finally:
            if should_close:
                db.close()


# -----------------------------
# 내부 유틸
# -----------------------------
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# -----------------------------
# JWT 유틸
# -----------------------------
SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-change-me")
ALGORITHM = os.getenv("ALGORITHM", "HS256")


def create_access_token(subject: str | int, extra: Optional[Dict[str, Any]] = None) -> str:
    payload: Dict[str, Any] = {"sub": str(subject)}
    if extra:
        payload.update(extra)
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def verify_legacy_password(plain_password: str, phone: str, stored_hash: str) -> bool:
    """기존 해시 로직과 동일한 방식으로 검증"""
    return hashlib.sha256((plain_password + phone).encode()).hexdigest() == stored_hash


# -----------------------------
# 엔드포인트
# -----------------------------
@router.post("/register", response_model=UserOut, response_model_exclude_none=True, status_code=201)
def register_user_api(data: RegisterIn, db: Session = Depends(get_db)):
    """회원가입 (이름 필수 / 닉네임은 기본값 'none')"""

    if db.scalar(select(User.id).where(User.phone == data.phone)):
        raise HTTPException(status_code=409, detail="이미 등록된 전화번호입니다.")

    reg = Register(
        phone=data.phone,
        password=data.password,
        name=data.name,
        gender=data.gender,
        age=data.age,
        timezone=data.timezone,
    )

    try:
        user = reg.register_user(db=db)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    return user


@router.post("/login", response_model=TokenOut)
def login_api(data: LoginIn, db: Session = Depends(get_db)):
    """로그인"""
    user = db.scalar(select(User).where(User.phone == data.phone))
    if not user or not verify_legacy_password(data.password, data.phone, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="전화번호 또는 비밀번호가 올바르지 않습니다.",
        )

    token = create_access_token(subject=user.id, extra={"nickname": user.nickname})
    return TokenOut(access_token=token, user=user)


@router.put("/users/{user_id}", response_model=UserOut)
def update_user_api(
    user_id: int = Path(..., ge=1),
    data: UpdateUserIn = None,
    db: Session = Depends(get_db),
):
    """프로필 수정 (profile_setup.dart에서 호출)"""
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="유저를 찾을 수 없습니다.")

    if data.nickname is not None:
        candidate = data.nickname.strip()
    
        # 중복(본인 제외)만 체크
        exists = db.scalar(
            select(User.id).where(User.nickname == candidate, User.id != user_id)
        )
        if exists:
            raise HTTPException(status_code=409, detail="이미 사용 중인 닉네임입니다.")
        user.nickname = candidate

    if data.gender is not None:
        user.gender = data.gender
    if data.age is not None:
        user.age = data.age
    if data.bio is not None:
        user.bio = data.bio
    if data.profile_picture is not None:
        user.profile_picture = data.profile_picture

    db.add(user)
    db.commit()
    db.refresh(user)
    return user

@router.get("/users/{user_id}", response_model=UserOut, response_model_exclude_none=True)
def get_user(user_id: int, db: Session = Depends(get_db)):
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user
