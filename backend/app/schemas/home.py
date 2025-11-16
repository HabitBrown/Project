# app/schemas/home.py
from datetime import time
from typing import List
from pydantic import BaseModel


class HomeHabitItemOut(BaseModel):

    user_habit_id: int
    title: str
    method: str          # "photo" / "text"
    deadline_local: time # 로컬 기준 마감 시각
    progress: float = 0  # 일단 0.0, 나중에 인증 성공률 넣을 수 있음

    class Config:
        orm_mode = True


class HomeSummaryOut(BaseModel):
    """
    홈 요약 + 홈 카드에 들어갈 습관 리스트.
    """
    # 기존 숫자 3개 (이미 프론트에서 쓰는 값)
    today_cert_count: int       # 오늘 인증 성공 횟수
    current_duel_count: int     # 현재 진행 중인 듀얼 개수
    solo_habit_count: int       # 혼자 하는 습관 개수

    # 혼자 하는 습관
    today_habits: List[HomeHabitItemOut]

    # 같이 경쟁하는 습관
    fighting_habits: List[HomeHabitItemOut]

    class Config:
        orm_mode = True
