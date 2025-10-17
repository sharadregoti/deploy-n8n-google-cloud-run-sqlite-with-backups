#!/bin/sh
# backup.sh - simple n8n backup loop using rclone

set -eu

BUCKET_NAME="${BACKUP_BUCKET:-my-n8n-backups}"
BACKUP_PREFIX="${BACKUP_PREFIX:-backups}"
BACKUP_DIR="${BACKUP_DIR:-/tmp/n8n-backup}"
INTERVAL_SEC="${BACKUP_INTERVAL_SEC:-3600}"
RCLONE_REMOTE="${RCLONE_REMOTE:-n8n-gcs}"

mkdir -p "${BACKUP_DIR}"

STOP=0
trap 'echo "backup.sh: stopping after current iteration"; STOP=1' TERM INT

upload_file() {
  src="$1"
  base=$(basename "$src")
  # Remove timestamp from base name for latest path
  base_no_timestamp=$(echo "$base" | sed -E 's/-[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}Z//')

  # Upload to timestamped folder
  dest="${RCLONE_REMOTE}:${BUCKET_NAME}/${BACKUP_PREFIX}/${TIMESTAMP}/${base}"
  echo "backup.sh: uploading ${src} -> ${dest}"
  rclone copyto "$src" "$dest" || echo "backup.sh: warning: failed to upload ${src}"

  # Update latest with non-timestamped name and force overwrite
  latest="${RCLONE_REMOTE}:${BUCKET_NAME}/${BACKUP_PREFIX}/latest/${base_no_timestamp}"
  echo "backup.sh: updating latest ${src} -> ${latest}"
  rclone copyto "$src" "$latest" || echo "backup.sh: warning: failed to update latest pointer"
}

echo "backup.sh: backup loop starting (interval ${INTERVAL_SEC}s)"

while [ "$STOP" = "0" ]; do
  TIMESTAMP=$(date -u +'%Y-%m-%dT%H-%M-%SZ')
  echo "backup.sh: starting backup for ${TIMESTAMP}"

  WORKFLOW_FILE="${BACKUP_DIR}/workflows-${TIMESTAMP}.json"
  CRED_FILE="${BACKUP_DIR}/credentials-${TIMESTAMP}.json"

  # Export workflows (may fail if none exist)
  if n8n export:workflow --all --output="$WORKFLOW_FILE"; then
    upload_file "$WORKFLOW_FILE"
  else
    echo "backup.sh: no workflows to export yet"
    rm -f "$WORKFLOW_FILE"
  fi

  # Export credentials (may fail if none exist)
  if n8n export:credentials --all --output="$CRED_FILE"; then
    upload_file "$CRED_FILE"
  else
    echo "backup.sh: no credentials to export yet"
    rm -f "$CRED_FILE"
  fi

  # remove local files older than 3 days
  find "$BACKUP_DIR" -type f -name '*.json' -mtime +3 -exec rm -f {} \; || true

  # sleep in small chunks to respond quickly to stop signals
  slept=0
  while [ "$slept" -lt "$INTERVAL_SEC" ]; do
    if [ "$STOP" != "0" ]; then
      echo "backup.sh: stopping sleep early"
      break
    fi
    sleep_chunk=5
    remaining=$((INTERVAL_SEC - slept))
    if [ "$remaining" -lt "$sleep_chunk" ]; then
      sleep_chunk=$remaining
    fi
    sleep "$sleep_chunk"
    slept=$((slept + sleep_chunk))
  done
done

echo "backup.sh: exiting gracefully"
exit 0
