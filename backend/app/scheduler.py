from apscheduler.schedulers.background import BackgroundScheduler
from app.database import SessionLocal
from app.models.user import User
from app.routers.certification import (
    auto_fail_overdue_habits_for_today,
    create_deadline_reminders_10min_before,
)

scheduler = BackgroundScheduler()

def run_daily_tasks():
    db = SessionLocal()
    try:
        users = db.query(User).all()

        for user in users:
            auto_fail_overdue_habits_for_today(db, user)
            create_deadline_reminders_10min_before(db, user)

    finally:
        db.close()


def start_scheduler():
    # 1분마다 실행
    scheduler.add_job(run_daily_tasks, 'interval', minutes=1)
    scheduler.start()
