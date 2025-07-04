#!/bin/bash

REQUIRED=(
".github/workflows"
"requirements.txt"
"package.json"
"main.py"
"playwright_varta.py"
"product_match.py"
"vegvesen_lookup.py"
"frontend"
"public"
"docker-compose.yml"
"langflow"
"tests"
)

echo "Følgende må være tilstede:"
for f in "${REQUIRED[@]}"; do
  if [ ! -e "$f" ]; then
    echo "❌ Mangler: $f"
  else
    echo "✅ Fins:    $f"
  fi
done
