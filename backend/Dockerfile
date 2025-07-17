FROM python:3.12-slim

WORKDIR /app

# Kopier kun requirements først for cache
COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# Kopier all backend-kode
COPY . .

# Start FastAPI med uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
