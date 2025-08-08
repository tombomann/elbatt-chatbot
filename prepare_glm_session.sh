#!/bin/bash
echo "Forbereder GLM-4.5 økt..."
echo "========================"

# Oppdater kontekst
./glm-sync.sh

echo ""
echo "Kontekstfil generert. Kopier følgende tekst til din GLM-4.5 økt:"
echo "==============================================================="
cat glm-context.txt
echo "==============================================================="

echo ""
echo "Tips: Start GLM-4.5 med: 'Hei GLM-4.5! Jeg fortsetter arbeidet med elbatt-chatbot prosjektet. Her er konteksten fra forrige økt:'"
echo "Og lim inn teksten over."
