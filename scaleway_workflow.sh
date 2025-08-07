#!/bin/bash

echo "Scaleway arbeidsflyt for GLM-4.5 økt..."
echo "======================================="

echo "1. Forbered GLM-4.5 økt..."
./prepare_glm_session.sh

echo ""
echo "2. Vent på at du fullfører GLM-4.5 økten..."
echo "   - Kopier konteksten til GLM-4.5"
echo "   - Gjør endringene dine"
echo "   - Trykk ENTER når du er ferdig"
read

echo "3. Avslutter økt og deployer til Scaleway..."
./end_glm_session.sh

echo "4. Deployer til Scaleway..."
./deploy_to_scaleway.sh

echo "5. Verifiser deployment..."
echo "   Sjekk https://chatbot.elbatt.no/test-chatbot.html"

echo "Arbeidsflyt fullført!"
