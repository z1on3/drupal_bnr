#!/bin/bash

# ==== Load environment variables ====
export $(grep -v '^#' .env | xargs)

# ==== Timestamp Configuration ====
export TZ='Asia/Singapore'
DATE=$(date +%F_%I-%M%p)  # e.g., 2025-05-02_12-20PM
START_TIME=$(date "+%Y-%m-%d %I:%M:%S %p %Z")

TMP_DIR="/tmp/drupal_backup_$DATE"
ARCHIVE_NAME="${BACKUP_PREFIX:-drupal_backup}_$DATE.tar.gz"

mkdir -p "$BACKUP_DIR"
LOG_FILE="$BACKUP_DIR/backup.log"

echo "[*] Starting Drupal backup from: $DRUPAL_DIR"
echo "[*] Backup will be saved as: $ARCHIVE_NAME"
echo "[LOG] Backup started at $START_TIME [Archive: $ARCHIVE_NAME]" >> "$LOG_FILE"

mkdir -p "$TMP_DIR"

# 1. Copy codebase excluding 'files'
echo "[*] Backing up codebase..."
rsync -a --exclude='sites/default/files' "$DRUPAL_DIR/" "$TMP_DIR/codebase"

# 2. Backup files directory
echo "[*] Backing up files directory..."
rsync -a "$DRUPAL_DIR/sites/default/files" "$TMP_DIR/files"

# 3. Dump database
echo "[*] Backing up database..."
mysqldump --single-transaction --skip-lock-tables --no-tablespaces \
  -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$TMP_DIR/database.sql"

# 4. Create archive
echo "[*] Creating archive..."
tar -czf "$BACKUP_DIR/$ARCHIVE_NAME" -C "/tmp" "$(basename "$TMP_DIR")"

# 5. Cleanup
rm -rf "$TMP_DIR"

END_TIME=$(date "+%Y-%m-%d %I:%M:%S %p %Z")
echo "[✔] Backup completed: $BACKUP_DIR/$ARCHIVE_NAME"
echo "[LOG] Backup completed at $END_TIME [Archive: $ARCHIVE_NAME]" >> "$LOG_FILE"
