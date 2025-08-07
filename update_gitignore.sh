#!/bin/bash

echo "Oppdaterer .gitignore..."

# Legg til nye oppføringer hvis de ikke allerede finnes
grep -q "*.backup" .gitignore || echo "*.backup" >> .gitignore
grep -q "glm-context.txt" .gitignore || echo "glm-context.txt" >> .gitignore
grep -q "session_summary.json" .gitignore || echo "session_summary.json" >> .gitignore
grep -q "__pycache__/" .gitignore || echo "__pycache__/" >> .gitignore
grep -q "*.pyc" .gitignore || echo "*.pyc" >> .gitignore

echo ".gitignore oppdatert:"
cat .gitignore | grep -E "(backup|glm-context|session_summary|__pycache__|\.pyc)"
