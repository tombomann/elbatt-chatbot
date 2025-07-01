import openai
import os

# Filen du ønsker å fikse (her: første feilet test)
TARGET_FILE = "tests/test_main.py"
ERROR_MSG = os.environ.get("AI_AUTOFIX_ERROR", "Skriv om denne filen slik at den kjører grønt i pytest og dekker hovedlogikken. Returner kun gyldig Python.")

openai.api_key = os.environ["OPENAI_API_KEY"]

with open(TARGET_FILE, "r") as f:
    code = f.read()

prompt = f"""
Du er en erfaren Python-utvikler og testspesialist. Rett denne koden slik at alle tester går grønt:
---
Kode:
{code}
---
Feilmelding/logg:
{ERROR_MSG}
---
Returner kun gyldig kode for filen, ingen forklaring.
"""

response = openai.ChatCompletion.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": prompt}],
    max_tokens=1500
)

fixed_code = response.choices[0].message.content.strip()
with open(TARGET_FILE, "w") as f:
    f.write(fixed_code)
print("AI-fiks ferdig og skrevet til", TARGET_FILE)
