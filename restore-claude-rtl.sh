#!/bin/bash
set -euo pipefail

APP_PATH="${1:-/Applications/Claude.app}"
RESOURCES="$APP_PATH/Contents/Resources"
ASAR="$RESOURCES/app.asar"
LATEST_FILE="$HOME/ClaudeRTLBackups/latest"

[ -f "$LATEST_FILE" ] || {
  echo "No latest backup file found at:"
  echo "$LATEST_FILE"
  exit 1
}

BACKUP_DIR="$(cat "$LATEST_FILE")"

[ -d "$BACKUP_DIR" ] || {
  echo "Backup dir not found:"
  echo "$BACKUP_DIR"
  exit 1
}

[ -f "$BACKUP_DIR/app.asar" ] || {
  echo "Backup app.asar not found:"
  echo "$BACKUP_DIR/app.asar"
  exit 1
}

osascript -e 'tell application "Claude" to quit' 2>/dev/null || true
pkill -x "Claude" 2>/dev/null || true
sleep 2

sudo cp "$BACKUP_DIR/app.asar" "$ASAR"

find "$BACKUP_DIR" -name "Info.plist" -print0 | while IFS= read -r -d '' BACKUP_PLIST; do
  REL="${BACKUP_PLIST#$BACKUP_DIR/}"
  DEST="$APP_PATH/$REL"
  [ -f "$DEST" ] && sudo cp "$BACKUP_PLIST" "$DEST"
done

sudo codesign --force --deep --sign - "$APP_PATH"

echo "Restored Claude from:"
echo "$BACKUP_DIR"