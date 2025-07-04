import os
import openai
import re
import json
import subprocess
from pathlib import Path

# Krever at OPENAI_API_KEY er satt i GitHub Actions secrets
openai.api_key = os.getenv("OPENAI_API_KEY")

# 🔍 Finn siste feillogg (fra npm eller annet)
LOG_FILE = "/tmp/ci_error_log.txt"  # Legg inn output fra feilet jobb her
if not Path(LOG_FILE).exists():
    print("❌ Ingen feillogg funnet.")
    exit(1)

with open(LOG_FILE, "r") as f:
    log = f.read()

# 🧠 Send feilmeldingen til OpenAI og be om forslag til fiks
prompt = f"""
Du er en erfaren JavaScript-utvikler. Her er logg fra en feilet npm/CI-jobb:
