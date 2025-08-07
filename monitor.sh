#!/bin/bash
# Overvåkning av ytelse

echo "📊 Performance Monitor"
echo "===================="

# CPU og Memory bruk
echo "CPU og Memory:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Disk bruk
echo -e "\nDisk bruk:"
df -h | grep -E "(Filesystem|/dev/sda)"

# Network statistikk
echo -e "\nNetwork:"
docker network ls
docker network inspect elbatt-chatbot_app-network | grep -A 10 "Containers"
