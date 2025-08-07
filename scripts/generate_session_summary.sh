#!/bin/bash

echo "Genererer prosjektsammendrag for GLM-4.5..."
cd "$(dirname "$0")/.."
python3 backend/session_summary.py
echo "Sammendrag lagret i session_summary.json"
