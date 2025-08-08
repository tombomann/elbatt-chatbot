FROM python:3.12-slim

# Installer systemavhengigheter inkludert build-verktøy
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Kopier requirements-fil og installer Python-avhengigheter
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Kopier resten av applikasjonen
COPY . .

# Start kommando
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
