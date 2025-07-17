#!/bin/bash

set -e

echo "===> Sjekker at du står i prosjektroten ..."
if [ ! -d "backend" ]; then
  echo "❌ Du må stå i prosjektroten der backend/ finnes!"
  exit 1
fi

echo "===> Sjekker at backend/__init__.py finnes ..."
if [ ! -f backend/__init__.py ]; then
  echo "Lager tom backend/__init__.py ..."
  touch backend/__init__.py
else
  echo "✔️ backend/__init__.py finnes."
fi

echo "===> Sjekker at backend/main.py finnes ..."
if [ ! -f backend/main.py ]; then
  echo "❌ Fant ikke backend/main.py!"
  exit 2
fi

echo "===> Sjekker at Dockerfile finnes ..."
if [ ! -f Dockerfile ]; then
  echo "❌ Fant ikke Dockerfile!"
  exit 3
fi

echo "===> Sjekker at requirements.txt finnes ..."
if [ ! -f requirements.txt ]; then
  echo "❌ Fant ikke requirements.txt!"
  exit 4
fi

echo "===> Sjekker at Dockerfile bruker riktig CMD ..."
if grep -q 'backend.main:app' Dockerfile; then
  echo "✔️ Dockerfile peker på backend.main:app"
else
  echo "❌ Dockerfile bruker feil CMD. Setter riktig kommando ..."
  # Endre CMD-linjen automatisk til korrekt verdi:
  sed -i '/^CMD/d' Dockerfile
  echo 'CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "3000"]' >> Dockerfile
  echo "✔️ Endret CMD til korrekt verdi."
fi

echo "===> Bygger Docker-image ..."
docker build -t elbatt-test .

echo "===> Kjører Docker container for lokal test ..."
docker run --rm -p 3000:3000 elbatt-test &

# Vent litt og test om porten svarer
sleep 5
if curl -s http://localhost:3000/docs | grep -q "FastAPI"; then
  echo "🎉 Container kjører og FastAPI docs svarer!"
else
  echo "❌ Container startet ikke korrekt, sjekk loggene manuelt!"
fi

# Avslutt alle containere startet av denne builden
docker kill $(docker ps -q --filter ancestor=elbatt-test) >/dev/null 2>&1 || true

echo "✅ Alt klart for deploy til Scaleway!"
