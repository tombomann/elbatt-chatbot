import openai
import os

# Angi hvilken fil som skal rettes (f.eks. hoved-testfil)
TARGET_FILE = "frontend/src/App.test.js"
ERROR_MSG = os.environ.get("AI_AUTOFIX_ERROR", "Rett denne filen slik at alle tester går grønt med jest/react-scripts. Returner kun gyldig JavaScript.")

openai.api_key = os.environ["OPENAI_API_KEY"]

with open(TARGET_FILE, "r") as f:
    code = f.read()

prompt = f"""
Du er en erfaren React/JS-utvikler og testspesialist. Rett denne koden slik at alle tester går grønt med jest:
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
    max_tokens=1800
)

fixed_code = response.choices[0].message.content.strip()
with open(TARGET_FILE, "w") as f:
    f.write(fixed_code)
print("AI-fiks ferdig og skrevet til", TARGET_FILE)
