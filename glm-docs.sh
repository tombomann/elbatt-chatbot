#!/bin/bash
# Oppdater dokumentasjon for GLM-4.5

echo "📚 Updating GLM-4.5 documentation..."

# 1. Sjekk for GLM-4.5 endringer
if git log --oneline --since="1 week ago" | grep -i "glm"; then
    echo "GLM-4.5 changes detected, updating documentation..."
    
    # 2. Oppdater README
    # Her kan du legge til logikk for å oppdatere README automatisk
    
    # 3. Oppdater feature tracker
    echo "$(date): Updated GLM-4.5 features" >> GLM-4.5-FEATURES.md
    
    # 4. Commit og push endringer
    git add GLM-4.5-FEATURES.md README.md
    git commit -m "docs: Update GLM-4.5 documentation"
    git push origin main
    
    echo "✅ GLM-4.5 documentation updated"
else
    echo "No GLM-4.5 changes to document"
fi
