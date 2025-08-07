#!/bin/bash

echo "Setter opp Scaleway monitoring..."
echo "================================"

# 1. Installer Scaleway agent
echo "1. Installerer Scaleway agent..."
curl -s https://raw.githubusercontent.com/scaleway/scaleway-agent/master/install.sh | sh

# 2. Konfigurer monitoring for applikasjon
echo "2. Konfigurerer applikasjonsmonitoring..."
cat > /etc/scaleway/agent.d/elbatt-chatbot.yml << 'MONITOR'
checks:
  - type: http
    url: http://localhost:8000/api/health
    interval: 30s
    timeout: 10s
    
  - type: tcp
    port: 8000
    interval: 30s
    timeout: 10s
    
  - type: tcp
    port: 3001
    interval: 30s
    timeout: 10s
    
  - type: process
    name: redis-server
    interval: 60s
MONITOR

# 3. Restart agent
echo "3. Restarter Scaleway agent..."
systemctl restart scaleway-agent

echo "Monitoring satt opp!"
