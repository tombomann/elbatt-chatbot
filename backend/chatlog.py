import time
import json
from pathlib import Path

LOG_FILE = Path("/root/elbatt-chatbot/chatlog.jsonl")

def log_chat(user_id, message, response):
    log_entry = {
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "user_id": user_id,
        "message": message,
        "response": response
    }
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(json.dumps(log_entry, ensure_ascii=False) + "\n")
