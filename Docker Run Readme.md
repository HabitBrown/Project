## Backend Container Setup
### Required Environment Variables
- HASHBROWN_DB_URL: SQLAlchemy MySQL URL, e.g. mysql+pymysql://user:pass@mysql:3306/hashbrown?charset=utf8mb4
- SECRET_KEY: JWT signing secret
- ALGORITHM: JWT algorithm (default HS256)
- HASHBROWN_UPLOAD_ROOT: optional path for static uploads (default /app/uploads in container)

### Build & Run
---
```
docker build -t hashbrown-backend ./backend
docker run --rm -p 8000:8000 \
  -e HASHBROWN_DB_URL="mysql+pymysql://user:pass@mysql:3306/hashbrown?charset=utf8mb4" \
  -e SECRET_KEY="change-me" \
  -v $(pwd)/backend/uploads:/app/uploads \
  hashbrown-backend
```

### Initialize Database Schema via Docker
> Run this once per environment before the app starts serving traffic.

### Using `docker run`
---
```
docker run --rm \
  -e HASHBROWN_DB_URL="mysql+pymysql://user:pass@mysql:3306/hashbrown?charset=utf8mb4" \
  -v $(pwd)/backend/uploads:/app/uploads \
  --entrypoint python \
  hashbrown-backend \
  -m app.create_db
```

### Using Docker Compose override
---
```
services:
  backend:
    build: ./backend
    environment:
      HASHBROWN_DB_URL: mysql+pymysql://user:pass@mysql:3306/hashbrown?charset=utf8mb4
      SECRET_KEY: change-me
    volumes:
      - ./backend/uploads:/app/uploads
    ports:
      - "8000:8000"
  db-init:
    image: hashbrown-backend
    depends_on:
      - backend
    entrypoint: ["python", "-m", "app.create_db"]
    environment:
      HASHBROWN_DB_URL: mysql+pymysql://user:pass@mysql:3306/hashbrown?charset=utf8mb4
```

Ensure the MySQL database exists (run python -m app.create_db once if needed) before starting the container, or provide an external migration step.

