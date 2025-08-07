#!/bin/bash
# Generer ukentlig rapport

WEEKLY_REPORT="/tmp/weekly-report.txt"

echo "Ukentlig Rapport - Elbatt Chatbot" > "$WEEKLY_REPORT"
echo "Generert: $(date)" >> "$WEEKLY_REPORT"
echo "=================================" >> "$WEEKLY_REPORT"

# System status
echo -e "\n🖥️ System Status:" >> "$WEEKLY_REPORT"
docker-compose ps >> "$WEEKLY_REPORT"

# Ressursbruk
echo -e "\n📊 Ressursbruk:" >> "$WEEKLY_REPORT"
docker stats --no-stream --format "{{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" >> "$WEEKLY_REPORT"

# Logg statistikk
echo -e "\n📈 Logg Statistikk:" >> "$WEEKLY_REPORT"
echo "Total requests: $(docker-compose logs backend | grep -c 'POST /api/chat')" >> "$WEEKLY_REPORT"
echo "Errors: $(docker-compose logs backend | grep -c 'ERROR')" >> "$WEEKLY_REPORT"

# Send rapport (eksempel med mail)
# mail -s "Elbatt Chatbot Ukentlig Rapport" tomarnejensen@gmail.com < "$WEEKLY_REPORT"

cat "$WEEKLY_REPORT"
