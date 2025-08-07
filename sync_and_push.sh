#!/bin/bash

echo "Synkroniserer og pusher endringer..."

# Pull først for å unngå konflikter
echo "Puller siste endringer fra remote..."
git pull origin main

# Legg til alle endringer
echo "Legger til endringer..."
git add .

# Be om commit-melding
echo "Skriv commit-melding:"
read commit_msg

# Commit
git commit -m "$commit_msg"

# Push
echo "Pusher til remote..."
git push origin main

echo "Synkronisering fullført!"
