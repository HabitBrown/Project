# Backend app router
from app.models.duel import Duel
from app.models.user import User

# Datetime
from datetime import date

# Duel의 경우
# - pushType: "challenge"
# - senderName: 도전자의 이름
# - title: 습관 제목
# - action: ""
# - dateText: ""

# Certification의 경우
# - pushType: "certification"
# - senderName: None
# - title: 습관 제목
# - action: ""
# - dateText: ""

def transfer_data_type(uid: int, input_type: str, title: str, action: str = "") -> dict:
    if input_type not in {"challenge", "certification", "etc"}:
        raise ValueError("Invalid input type. Must be 'certification' or 'challenge'.")

    if title is None:
        raise ValueError("Title cannot be None.")

    now = date.today()

    model_mapping = {
        "pushType": input_type,
        "senderName": None,
        "title": title,
        "action": action,
        "dateText": now
    }

    if input_type == "challenge":
        # senderName은 도전자의 이름으로 설정
        # 그러면 duel로부터 도전자의 이름을 가져와야 함
        # 먼저 duel을 찾아야 함
        # uid는 도전받는 사람의 id이므로 duel에서 owner_user_id가 uid인 것을 찾아야 함
        # 그리고 challenger_user_id로 사용자의 이름을 찾아야 함
        duel_id = Duel.select().where(
            Duel.owner_user_id == uid
        ).first()
        challenger_id = duel_id.challenger_user_id
        challenger_user = User.select().where(User.id == challenger_id).first()
        if challenger_user is None:
            raise ValueError(f"User with id {uid} not found.")
        model_mapping["senderName"] = challenger_user.name

    return model_mapping