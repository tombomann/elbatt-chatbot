# Elbatt Chatbot
Elbatt Chatbot er et lite fullstack-prosjekt som kombinerer en FastAPI-backend med en React-basert frontend. Løsningen viser hvordan man kan bygge en enkel kundeservice-chatbot som benytter OpenAI sammen med andre tjenester.

## Oppsett

1. Installer **Docker** og **Node.js** (>=20) på maskinen din.
2. Lag en fil `.env` i prosjektroten med minst følgende variabler:
   ```
   OPENAI_API_KEY=din-openai-nokkel
   VEGVESEN_API_KEY=din-vegvesen-nokkel
   ```
   Valgfrie variabler:
   ```
   ALLOWED_ORIGINS="https://elbatt.no,https://www.elbatt.no"
   STATIC_DIR=/app/public
   ASSETS_DIR=/app/assets
   ```

## Starte med Docker

Kjør både backend og frontend samtidig med:
```bash
docker compose up --build
```
Backend er da tilgjengelig på `http://localhost:8000` og frontend på `http://localhost`.

## Starte backend manuelt

```bash
cd backend
pip install -r ../requirements.txt
uvicorn main:app --reload
```

## Starte frontend manuelt

=======
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


Utviklerserveren starter normalt på port 3000 og kaller backend på `http://localhost:8000`.
=======
Backend kjører da på `http://localhost:8000` og frontend på `http://localhost:3000`.

