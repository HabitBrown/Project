from app.models.base import create_all

if __name__ == "__main__":
    print(" Creating all tables in the database...")
    create_all()
    print("Done!")
