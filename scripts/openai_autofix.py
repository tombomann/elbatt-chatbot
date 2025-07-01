import openai, os, glob

openai.api_key = os.environ.get("OPENAI_API_KEY")

# Legg inn flere relevante filer her!
filer = [
    "frontend/src/App.js",
    "backend/main.py"
]
for fil in filer:
    if not os.path.isfile(fil):
        continue
    with open(fil) as f:
        kode = f.read()
    prompt = f"Du er en erfaren utvikler. Retter du kodefeil, bugs, og CI-feil i følgende kode? Returner kun den forbedrede koden:\n\n{kode}"
    resp = openai.ChatCompletion.create(
        model="gpt-4o",
        messages=[{"role": "user", "content": prompt}]
    )
    ny_kode = resp.choices[0].message.content
    with open(fil, "w") as f:
        f.write(ny_kode)
    print(f"✅ Oppdatert: {fil}")
