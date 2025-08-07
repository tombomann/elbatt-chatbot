FROM python:3.12-slim

WORKDIR /app

# Installer systemavhengigheter inkludert curl for health checks
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Kopier requirements-fil og installer Python-avhengigheter
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Kopier resten av applikasjonen
COPY . .

# Expose port
EXPOSE 8000

# Start kommando
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
