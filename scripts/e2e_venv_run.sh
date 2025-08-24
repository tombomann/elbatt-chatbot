#!/usr/bin/env bash
set -euo pipefail

# Lager en egen venv for E2E
VENV="${VENV:-.venv-e2e}"
python3 -m venv "$VENV"
source "$VENV/bin/activate"
python -m pip install --upgrade pip

# Installer Playwright (Python) + nettlesere
pip install "playwright==1.47.0"
python -m playwright install chromium --with-deps

# Kjør testen
python tests/e2e/test_chat_on_site.py
