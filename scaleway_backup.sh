#!/bin/bash

echo "Scaleway backup prosedyre..."
echo "==========================="

# 1. Lag database dump
echo "1. Lager backup av Redis..."
docker exec elbatt-chatbot_redis_1 redis-cli SAVE
docker cp elbatt-chatbot_redis_1:/data/dump.rdb ./redis_backup_$(date +%Y%m%d_%H%M%S).rdb

# 2. Backup til Scaleway Object Storage
echo "2. Laster opp til Scaleway Object Storage..."
# Installer scw CLI hvis ikke installert
if ! command -v scw &> /dev/null; then
    echo "Installerer Scaleway CLI..."
    curl -s https://raw.githubusercontent.com/scaleway/scaleway-cli/master/install.sh | sh
fi

# Last opp backup
scw object sync ./redis_backup_*.rdb s3://elbatt-backups/redis/

# 3. Rydd gamle lokale backups
echo "3. Rydder gamle lokale backups..."
find ./ -name "redis_backup_*.rdb" -mtime +7 -delete

echo "Backup fullført!"
