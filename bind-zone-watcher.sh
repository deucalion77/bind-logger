#!/bin/bash

WATCH_DIR="/etc/bind/"
BACKUP_DIR="/var/backups/bind-zones"
LOG_FILE="/var/log/bind/dns-diff.log"
BPFTRACE_OUTPUT="/tmp/bpftrace-write.log"

mkdir -p "$BACKUP_DIR"
mkdir -p "$(dirname "$LOG_FILE")"
> "$BPFTRACE_OUTPUT"

# Initial backup
find "$WATCH_DIR" -type f | while read -r FILE; do
    BASENAME=$(basename "$FILE")
    cp "$FILE" "$BACKUP_DIR/${BASENAME}.last"
done

# Start bpftrace
stdbuf -oL bpftrace trace-writes.bt 2>>/dev/null > "$BPFTRACE_OUTPUT" &
echo "[DEBUG] bpftrace PID: $BPFTRACE_PID" >> /var/log/bind/debug.log
BPFTRACE_PID=$!
trap "kill $BPFTRACE_PID" EXIT

echo "[INFO] Watching $WATCH_DIR for changes..."

# Main monitor loop
inotifywait -m -e modify --format '%w%f' "$WATCH_DIR" | while read -r FILE; do
    BASENAME=$(basename "$FILE")
    TIMESTAMP=$(date -Iseconds)
    LAST_BACKUP="$BACKUP_DIR/${BASENAME}.last"
    NEW_BACKUP="$BACKUP_DIR/${BASENAME}.$(date +%s)"

    if [ -f "$LAST_BACKUP" ]; then
        DIFF=$(diff -u "$LAST_BACKUP" "$FILE")
        [ -z "$DIFF" ] && continue
    else
        DIFF="No previous backup available."
    fi

    cp "$FILE" "$NEW_BACKUP"
    cp "$FILE" "$LAST_BACKUP"

    sleep 0.2

# Match the modified file name from bpftrace output (filename only)

    ENTRY=$(grep "WRITE|" "$BPFTRACE_OUTPUT" | tail -n 1)

    if [ -n "$ENTRY" ]; then
        PID=$(echo "$ENTRY" | cut -d'|' -f2)
        USER_UID=$(echo "$ENTRY" | cut -d'|' -f3)
        USERNAME=$(getent passwd "$USER_UID" | cut -d: -f1)
    else
        PID=""
        USER_UID=""
        USERNAME=""
    fi

# Create full JSON string and escape newlines/tabs
    RAW_JSON=$(jq -n \
      --arg file "$BASENAME" \
      --arg time "$TIMESTAMP" \
      --arg user "$USERNAME" \
      --arg uid "$USER_UID" \
      --arg pid "$PID" \
      --arg diff "$DIFF" \
     '{
        file: $file,
        timestamp: $time,
        user: $user,
        uid: $uid,
        pid: $pid,
        diff: $diff
      }')

# Write JSON string as raw value in a "message" field
    echo "{\"message\": $(echo "$RAW_JSON" | jq -Rs '.') }" >> "$LOG_FILE"
done

