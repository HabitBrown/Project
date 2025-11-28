# app/routers/notification.py

from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo
from typing import List, Literal

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select, update

from app.database import SessionLocal
from app.models.notification import Notification
from app.models.user import User
from app.routers.register import get_current_user  

router = APIRouter(
    prefix="/notifications",
    tags=["Notifications"],
)


# ==========================
# DB 세션 의존성
# ==========================
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ==========================
#  내부: 알림 → 프론트용 payload 매핑
#   (AlarmItem.fromPush 에 맞춘 형태)
# ==========================
def _map_notification_to_alarm_payload(n: Notification) -> dict:
    """
    Notification 레코드를 Flutter AlarmItem.fromPush 에서
    기대하는 payload 형식으로 변환해주는 함수.
    """

    # 1) type → pushType 매핑
    # 모델의 type 값:
    #   "challenge","challenge_accepted","challenge_rejected",
    #   "cert_success","cert_fail","dispute","system"
    if n.type in ("challenge", "challenge_accepted", "challenge_rejected", "dispute"):
        push_type = "challenge"
    elif n.type in ("cert_success", "cert_fail"):
        push_type = "certification"
    else:  # "system" 또는 혹시 다른 값
        push_type = "etc"

    # 2) 날짜 문자열 만들기 (Asia/Seoul 기준, "YYYY. MM. DD" 포맷)
    date_text: str | None = None
    if n.created_at:
        # created_at 컬럼이 timezone=True 이므로 astimezone 사용
        try:
            seoul_dt = n.created_at.astimezone(ZoneInfo("Asia/Seoul"))
        except Exception:
            # 혹시 naive datetime 이 저장되어 있으면 그냥 그대로 씀
            seoul_dt = n.created_at
        date_text = seoul_dt.strftime("%Y. %m. %d")

    # 3) senderName 은 현재 Notification 모델에 없어서 일단 None 처리
    #    (나중에 필요하면 알림 생성 시 title/body 에 이름을 포함시키거나,
    #     별도 컬럼/조인으로 확장)
    sender_name = None

    # 4) title / action
    #    - title  → 상단 한 줄 텍스트
    #    - body   → 강조 텍스트(action)로 사용
    return {
        "id": n.id,
        "pushType": push_type,
        "senderName": sender_name,
        "title": n.title or "",
        "action": n.body or "",
        "dateText": date_text,
        "isRead": n.is_read,
        "deeplink": n.deeplink,
    }


# ==========================
#  GET /notifications
#   - 내 알림 전체 조회
#   - 최신순 정렬
# ==========================
@router.get("")
def list_notifications(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    로그인한 유저의 알림 목록을 최신순으로 반환.
    프론트에서는 각 항목을 AlarmItem.fromPush 에 그대로 넣어서 사용 가능.
    """

    stmt = (
        select(Notification)
        .where(Notification.user_id == current_user.id)
        .order_by(Notification.created_at.desc())
    )

    notifications: list[Notification] = db.execute(stmt).scalars().all()

    # 프론트용 payload 형태로 변환
    items = [_map_notification_to_alarm_payload(n) for n in notifications]

    return {
        "items": items,
        "count": len(items),
    }


# ==========================
#  PATCH /notifications/{noti_id}/read
#   - 단일 알림 읽음 처리
# ==========================
@router.patch("/{notification_id}/read", status_code=status.HTTP_204_NO_CONTENT)
def mark_notification_read(
    notification_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    특정 알림을 읽음 처리(is_read=True).
    """

    stmt = (
        select(Notification)
        .where(
            Notification.id == notification_id,
            Notification.user_id == current_user.id,
        )
    )
    noti: Notification | None = db.execute(stmt).scalar_one_or_none()

    if noti is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found.",
        )

    if noti.is_read:
        # 이미 읽음이면 그냥 204 반환
        return

    noti.is_read = True
    db.add(noti)
    db.commit()


# ==========================
#  PATCH /notifications/read-all
#   - 내 알림 전체 읽음 처리
# ==========================
@router.patch("/read-all", status_code=status.HTTP_204_NO_CONTENT)
def mark_all_notifications_read(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    현재 유저의 모든 알림 is_read=True 로 변경.
    """

    stmt = (
        update(Notification)
        .where(
            Notification.user_id == current_user.id,
            Notification.is_read == False,  # noqa: E712
        )
        .values(is_read=True)
    )
    db.execute(stmt)
    db.commit()
