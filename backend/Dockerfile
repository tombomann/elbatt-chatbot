FROM python:3.10-slim

# Sett arbeidskatalog
WORKDIR /app

# Kopier requirements først for å cache dependencies
COPY requirements.txt .

# Installer dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Kopier resten av app-koden
COPY . .

# Eksponer porten som uvicorn bruker
EXPOSE 8000

# Start uvicorn-serveren ved container-start
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
