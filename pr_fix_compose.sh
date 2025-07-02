#!/bin/bash
set -e

BRANCH="fix/docker-compose-env"

git checkout -b $BRANCH

cat > docker-compose.yml <<EOF
version: '3.8'

services:
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    ports:
      - "8000:8000"
    env_file:
      - .env
    environment:
      OPENAI_API_KEY: \${OPENAI_API_KEY}
      VEGVESEN_API_KEY: \${VEGVESEN_API_KEY}
      VAR1: value1
      VAR2: value2
    restart: unless-stopped

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    ports:
      - "80:80"
    restart: unless-stopped
EOF

git add docker-compose.yml
git commit -m "Fiks: Docker Compose environment YAML-feil"
git push origin $BRANCH

gh pr create --title "Fiks: Docker Compose environment YAML-feil" --body "Rettet environment-section slik at Compose fungerer i CI/CD og GitHub Actions" --base main --head $BRANCH --reviewer tombomann

echo "✅ PR er opprettet! Godkjenn i GitHub-grensesnittet."
