FROM python:3.12-slim

    ENV PYTHONDONTWRITEBYTECODE=1 \
        PYTHONUNBUFFERED=1 \
        PIP_NO_CACHE_DIR=1

    WORKDIR /app

    # System packages needed for Playwright (Chromium) + networking
    RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl wget unzip xvfb \
        libasound2 libatk1.0-0 libatk-bridge2.0-0 libatspi2.0-0 \
        libc6 libcairo2 libcups2 libdbus-1-3 libdrm2 libexpat1 \
        libfontconfig1 libgbm1 libglib2.0-0 libgtk-3-0 libnss3 libnspr4 \
        libpango-1.0-0 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 \
        libxcursor1 libxdamage1 libxext6 libxfixes3 libxi6 libxrandr2 \
        libxrender1 libxss1 libxtst6 libu2f-udev libvulkan1 \
      && rm -rf /var/lib/apt/lists/*

    COPY requirements.txt ./
    RUN pip install --upgrade pip wheel && pip install -r requirements.txt

    # If playwright is installed, fetch browsers (no-op if playwright absent)
    RUN python - <<'PY'
import importlib.util, subprocess, sys
spec = importlib.util.find_spec('playwright')
if spec is not None:
    subprocess.check_call(['python','-m','playwright','install','--with-deps','chromium'])
else:
    print('playwright not installed; skipping browser install')
PY

    # Copy project files (expects chatbot_api.py and services/ in context)
    COPY . .

    ENV PORT=8000
    EXPOSE 8000

    CMD [ "uvicorn", "chatbot_api:app", "--host", "0.0.0.0", "--port", "8000" ]
