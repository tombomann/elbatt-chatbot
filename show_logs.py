import json

logfile = "/root/elbatt-chatbot/chat_logs.jsonl"

try:
    with open(logfile, "r", encoding="utf-8") as f:
        for line in f:
            entry = json.loads(line)
            print(f"[{entry['timestamp']}] User: {entry['message']}")
            print(f"  Response: {entry['response']}\n")
except FileNotFoundError:
    print(f"Filen {logfile} finnes ikke. Ingen logger enda.")
except Exception as e:
    print(f"Feil ved lesing av logg: {e}")
