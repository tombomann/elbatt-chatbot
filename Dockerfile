# Base med Playwright for stabil Chromium i container
FROM mcr.microsoft.com/playwright/python:v1.47.0-jammy

WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

COPY requirements.txt /app/
RUN pip install --upgrade pip && pip install -r requirements.txt

# Kopier kode
COPY . /app

# Playwright deps (image har dem, men sørg for at chromium er klar)
RUN playwright install --with-deps chromium

# Serverless Containers gir PORT env – bruk den
ENV PORT=8000
EXPOSE 8000

# Non-root
RUN adduser --disabled-password --gecos "" appuser && chown -R appuser:appuser /app
USER appuser

CMD ["bash","-lc","uvicorn backend.main:app --host 0.0.0.0 --port ${PORT}"]
