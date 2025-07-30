# Elbatt Chatbot

Dette prosjektet gir et enkelt oppsett for en chatbot med FastAPI-backend og React-frontend.

## Krav
- Python 3.10+
- Node.js 18+

## Miljøvariabler
Følgende variabler må settes før du starter applikasjonen:

- `OPENAI_API_KEY` – nøkkel til OpenAI
- `FLOWISE_API_KEY` – nøkkel for import til Flowise

Du kan legge dem i en `.env`-fil eller eksportere dem i skallet ditt.

## Starte backend
```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn backend.main:app --reload
```

## Starte frontend
```bash
cd frontend
npm install
npm start
```

Backend kjører da på `http://localhost:8000` og frontend på `http://localhost:3000`.
