import os
import json

TEST_FILE = "/root/elbatt-chatbot/test_utf8.txt"
data = {"tekst": "ÆØÅ æøå", "emoji": "🤖"}

# Skriv til fil
with open(TEST_FILE, "w", encoding="utf-8") as f:
    f.write(json.dumps(data, ensure_ascii=False))

# Les fra fil
with open(TEST_FILE, "r", encoding="utf-8") as f:
    d = json.loads(f.read())

assert d["tekst"] == "ÆØÅ æøå"
assert d["emoji"] == "🤖"

print("UTF-8 test OK!")
