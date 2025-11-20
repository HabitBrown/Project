from sqlalchemy import select
from app.database import SessionLocal
from app.models.user import User, UserInterest, Interest, Follow
from app.models.user_habit import UserHabit
from sqlalchemy.exc import IntegrityError
from datetime import datetime, timezone


class UserInfo(object):
    def __init__(self, phone: str):
        self.phone = phone

    def select_user(self):
        """전화번호로 유저 1명 조회해서 감자캐기용 정보(dict)로 반환"""
        with SessionLocal() as session:
            user = session.scalars(
                select(User).where(User.phone == self.phone)
            ).first()

            if not user:
                return None

            # 1) 관심사(UserInterest → Interest.name)
            user_interests = session.scalars(
                select(UserInterest).where(UserInterest.user_id == user.id)
            ).all()

            interest_ids = [ui.interest_id for ui in user_interests]

            tags: list[str] = []
            if interest_ids:
                interests = session.scalars(
                    select(Interest).where(Interest.id.in_(interest_ids))
                ).all()
                # Interest.name 이라는 컬럼명이 있다고 가정
                tags = [it.name for it in interests]

            # 2) 완료된 습관만 가져오기
            completed = session.scalars(
                select(UserHabit)
                .where(
                    UserHabit.user_id == user.id,
                    UserHabit.status == "completed_success"
                )
                ).all()

            hashes: list[dict] = []
            
            for uh  in completed:
                hashes.append(
                        {
                            "hash_id": uh.id,
                            "title": uh.title,
                            "difficulty": uh.difficulty,
                        }
                )

            # 3) 최종 반환 데이터 (스키마와 키 이름을 맞춰야 함)
            return {
                "user_id": user.id,
                "name": user.nickname,
                "bio": user.bio or "",
                "tags": tags,
                "avatar_url": user.profile_picture,  # 컬럼명에 맞게 조정
                "hashes": hashes,
            }

    def follow_user(self, follower_id: int):
        """주어진 follower_id(나)가 self.phone 유저를 팔로우"""
        with SessionLocal() as session:
            user = session.scalars(
                select(User).where(User.phone == self.phone)
            ).first()

            if not user:
                raise ValueError("대상 유저를 찾을 수 없습니다.")

            uid = user.id
            follow = Follow(
                follower_id=follower_id, 
                followee_id=uid,
                created_at=datetime.now(timezone.utc),)

            session.add(follow)
            try:
                session.commit()
            except IntegrityError as e:
                session.rollback()
                # (예: 유니크 제약 위반 → 이미 팔로우 중)
                raise ValueError("팔로우 처리 중 에러가 발생했습니다.") from e

            session.refresh(follow)
            return follow
