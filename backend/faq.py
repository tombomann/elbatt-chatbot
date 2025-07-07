FAQ = [
    {"keywords": ["åpningstid", "åpent"], "answer": "Elbatt.no er åpent 24/7 på nett!"},
    {"keywords": ["retur", "angre"], "answer": "Du kan returnere batterier innen 14 dager, så lenge varen er ubrukt."},
    {"keywords": ["levering", "frakt"], "answer": "Vi sender med Bring og Posten. Normalt 1–3 dager leveringstid."},
    {"keywords": ["kontakt", "telefon", "mail"], "answer": "Kontakt oss på post@elbatt.no eller tlf. 72521600."},
    {"keywords": ["batteri", "bil", "elbiler", "fritid", "MC", "bobil"], "answer": "Vi har batterier til bil, elbil, båt, MC, bobil og fritid. Spør oss om du er usikker!"},
]

def faq_match(message: str):
    m = message.lower()
    for f in FAQ:
        if any(k in m for k in f["keywords"]):
            return f["answer"]
    return None
