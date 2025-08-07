#!/bin/bash
# Backup av viktig data

BACKUP_DIR="/backup/elbatt-chatbot"
DATE=$(date +%Y%m%d_%H%M%S)

# Lag backup mappe
mkdir -p "$BACKUP_DIR"

# Backup Redis data
docker exec elbatt-chatbot_redis_1 redis-cli SAVE
cp /var/lib/docker/volumes/elbatt-chatbot_redis_data/_data/dump.rdb "$BACKUP_DIR/redis_$DATE.rdb"

# Backup konfigurasjoner
cp .env "$BACKUP_DIR/env_$DATE.backup"
cp docker-compose.yml "$BACKUP_DIR/docker-compose_$DATE.yml"

# Fjern gamle backups (behold 7 dager)
find "$BACKUP_DIR" -name "*.backup" -mtime +7 -delete
find "$BACKUP_DIR" -name "*.rdb" -mtime +7 -delete
