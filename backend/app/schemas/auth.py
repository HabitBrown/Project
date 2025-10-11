from typing import Optional
from pydantic import BaseModel, Field

class RegisterIn(BaseModel):
    phone: str = Field(..., min_length=9, max_length=20)
    password: str = Field(..., min_length=6)
    name: str = Field(..., min_length=1, max_length=50)
    gender: Optional[str] = Field(None, pattern="^(M|F|N)$")
    age: Optional[int] = None
    timezone: Optional[str] = "Asia/Seoul"

class LoginIn(BaseModel):
    phone: str
    password: str

class UserOut(BaseModel):
    id: int
    phone: str
    name: str
    nickname: str
    gender: Optional[str] = None
    age: Optional[int] = None
    timezone: Optional[str] = None

    class Config:
        from_attributes = True  # SQLAlchemy -> Pydantic 변환 허용

class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut

class UpdateUserIn(BaseModel):
    nickname: Optional[str] = None
    gender: Optional[str] = Field(None, pattern="^(M|F|N)$")
    age: Optional[int] = None
    bio: Optional[str] = None
    profile_picture: Optional[str] = None
