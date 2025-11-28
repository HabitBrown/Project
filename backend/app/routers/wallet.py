# app/routers/wallet.py

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.models.user import User
from app.database import get_db
from app.routers.register import get_current_user

router = APIRouter(prefix="/me", tags=["Wallet"])


@router.get("/wallet")
def get_wallet(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user)
):
    return {"hb_balance": user.hb_balance}
