# Build stage
FROM python:3.12-slim AS base
WORKDIR /app
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 PYTHONUTF8=1 LANG=C.UTF-8 LC_ALL=C.UTF-8
COPY backend/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# Runtime
FROM python:3.12-slim
WORKDIR /app
ENV PYTHONUNBUFFERED=1 PYTHONUTF8=1 LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV DATA_FILE=/app/data/products.xlsx
COPY --from=base /usr/local/lib/python3.12 /usr/local/lib/python3.12
COPY --from=base /usr/local/bin /usr/local/bin
COPY backend /app
RUN mkdir -p /app/data && [ -s /app/data/products.xlsx ] || : > /app/data/products.xlsx
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
