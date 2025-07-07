def log_chat(user_id: str, message: str, response: str) -> None:
    import json, os
    from datetime import datetime

    LOG_FILE = "/root/elbatt-chatbot/chat_logs.jsonl"
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(
            json.dumps(
                {
                    "timestamp": datetime.utcnow().isoformat(),
                    "user_id": user_id,
                    "message": message,
                    "response": response,
                },
                ensure_ascii=False,
            )
            + "\n"
        )
