import os
import sys

# Sett inn de variablene du bruker i Scaleway
NEEDED = ["OPENAI_API_KEY", "LANGFLOW_API_KEY", "VEGVESEN_API_KEY"]

missing = [k for k in NEEDED if not os.getenv(k)]

if not missing:
    print("✅ Alle secrets er satt! 🚀")
    sys.exit(0)
else:
    print("❌ Mangler secrets:", ", ".join(missing))
    sys.exit(1)
