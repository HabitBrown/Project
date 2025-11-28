# app/routers/shop.py

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime

from app.database import get_db
from app.models.user import User
from app.models.shop import ShopItem, Order
from app.models.wallet import WalletTransaction
from app.schemas.shop import ShopItemBase, OrderCreate, OrderBase
from app.routers.register import get_current_user

router = APIRouter(prefix="/shop", tags=["Shop"])

@router.get("/items", response_model=list[ShopItemBase])
def get_items(db: Session = Depends(get_db)):
    items = db.query(ShopItem).all()
    return items

@router.post("/orders", response_model=OrderBase)
def create_order(
    payload: OrderCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user)
):
    item = db.query(ShopItem).filter(ShopItem.id == payload.item_id).first()
    if not item:
        raise HTTPException(404, "상품을 찾을 수 없어요.")

    if user.hb_balance < item.price_hb:
        raise HTTPException(400, "해시 브라운이 부족해요.")

    # 1) 잔액 차감
    db.query(User).filter(User.id == user.id).update(
        {User.hb_balance: User.hb_balance - item.price_hb}
    )

    # 2) 트랜잭션 기록
    tx = WalletTransaction(
        user_id=user.id,
        amount=-item.price_hb,
        reason="shop_purchase",
        ref_table="shop_items",
        ref_id=item.id,
        created_at=datetime.now()
    )
    db.add(tx)

    # 3) 주문 생성
    order = Order(
        user_id=user.id,
        item_id=item.id,
        status="placed",
        created_at=datetime.now()
    )
    db.add(order)

    db.commit()
    db.refresh(order)

    # order.item 자동 로딩 위해 refresh
    db.refresh(order)

    return order
