#!/bin/bash

# ==== Load environment variables ====
export $(grep -v '^#' .env | xargs)

# ==== Setup ====
export TZ='Asia/Singapore'
RESTORE_LOG="$BACKUP_DIR/restore.log"
START_TIME=$(date "+%Y-%m-%d %I:%M:%S %p %Z")

echo "[*] Looking for backups in $BACKUP_DIR..."

# Check for backups
BACKUPS=($(ls "$BACKUP_DIR"/*.tar.gz 2>/dev/null))
if [ ${#BACKUPS[@]} -eq 0 ]; then
    echo "❌ No backup files found in $BACKUP_DIR."
    echo "[LOG] Restore attempt failed at $START_TIME – no archives found." >> "$RESTORE_LOG"
    exit 1
fi

# Show backup options
echo "Available backups:"
for i in "${!BACKUPS[@]}"; do
    echo "[$i] $(basename "${BACKUPS[$i]}")"
done

# Ask for selection
read -p "Enter the number of the backup you want to restore: " CHOICE

# Validate input
if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -ge "${#BACKUPS[@]}" ]; then
    echo "❌ Invalid selection."
    echo "[LOG] Restore attempt failed at $START_TIME – invalid choice." >> "$RESTORE_LOG"
    exit 1
fi

SELECTED_BACKUP="${BACKUPS[$CHOICE]}"
TMP_DIR="/tmp/restore_$(date +%s)"
ARCHIVE_NAME=$(basename "$SELECTED_BACKUP")

echo "[*] Extracting backup..."
mkdir -p "$TMP_DIR"
tar -xzf "$SELECTED_BACKUP" -C "$TMP_DIR"

# Confirm overwrite
read -p "⚠️ This will overwrite existing code in $DRUPAL_DIR. Continue? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Cancelled."
    rm -rf "$TMP_DIR"
    echo "[LOG] Restore cancelled by user at $START_TIME [Archive: $ARCHIVE_NAME]" >> "$RESTORE_LOG"
    exit 0
fi

# Restore codebase
echo "[*] Restoring codebase..."
rsync -a --delete "$TMP_DIR/drupal_backup_"*/codebase/ "$DRUPAL_DIR/"

# Restore files
echo "[*] Restoring files directory..."
rsync -a "$TMP_DIR/drupal_backup_"*/files/ "$DRUPAL_DIR/sites/default/files"

# Restore database
echo "[*] Restoring database..."
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$TMP_DIR/drupal_backup_"*/database.sql

# Cleanup
rm -rf "$TMP_DIR"

END_TIME=$(date "+%Y-%m-%d %I:%M:%S %p %Z")
echo "[✔] Restore complete!"
echo "[LOG] Restore completed at $END_TIME [Archive: $ARCHIVE_NAME]" >> "$RESTORE_LOG"

