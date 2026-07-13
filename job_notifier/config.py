import os
from dotenv import load_dotenv

load_dotenv()

DISCORD_TOKEN = os.getenv("DISCORD_TOKEN")
CHANNEL_ID = int(os.getenv("CHANNEL_ID"))

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", 3306)),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
    "database": os.getenv("DB_NAME", "apply_db"),
}

NOTIFY_HOUR = int(os.getenv("NOTIFY_HOUR", 9))
NOTIFY_MINUTE = int(os.getenv("NOTIFY_MINUTE", 0))

_target = os.getenv("TARGET_JOB_PARTS", "").strip()
TARGET_JOB_PARTS = [p.strip() for p in _target.split(",") if p.strip()] if _target else []
