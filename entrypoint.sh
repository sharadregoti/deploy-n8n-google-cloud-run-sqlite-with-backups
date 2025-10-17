#!/bin/sh
set -eu

# Optional: debug logs
echo "entrypoint.sh: starting at $(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# rclone remote name must exist in env (e.g. RCLONE_REMOTE="n8n-gcs")
: "${RCLONE_REMOTE:?Environment variable RCLONE_REMOTE must be set (e.g. n8n-gcs)}"

# Optional: create the remote non-interactively if service account file provided
# (if GOOGLE_APPLICATION_CREDENTIALS is not set, rclone will rely on ADC/Workload Identity)
if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] && [ -f "${GOOGLE_APPLICATION_CREDENTIALS}" ]; then
  echo "entrypoint.sh: Ensuring rclone remote ${RCLONE_REMOTE} configured using service account file..."
  # If remote already exists this will return non-zero; ignore errors
  rclone config create "${RCLONE_REMOTE}" gcs service_account_file "${GOOGLE_APPLICATION_CREDENTIALS}" project_number "${GOOGLE_CLOUD_PROJECT:-}" 2>/dev/null || true
fi

# Config (env)
BUCKET_NAME="${BACKUP_BUCKET:-your-n8n-backups}"
BACKUP_PREFIX="${BACKUP_PREFIX:-n8n-backups}"

REMOTE_BASE="${RCLONE_REMOTE}:${BUCKET_NAME}/${BACKUP_PREFIX}"
WORKF_PATH="latest/workflows.json"
CRED_PATH="latest/credentials.json"   # keep consistent with your export naming

echo "entrypoint.sh: looking for latest backups at ${REMOTE_BASE} ..."

# Try to copy workflows (if present)
if rclone copyto "${REMOTE_BASE}/${WORKF_PATH}" /tmp/"${WORKF_PATH}" 2>/dev/null; then
  echo "entrypoint.sh: downloaded ${WORKF_PATH} to /tmp/${WORKF_PATH}"
else
  echo "entrypoint.sh: no ${WORKF_PATH} found at ${REMOTE_BASE} (continuing)"
fi

# Try to copy credentials (if present)
if rclone copyto "${REMOTE_BASE}/${CRED_PATH}" /tmp/"${CRED_PATH}" 2>/dev/null; then
  echo "entrypoint.sh: downloaded ${CRED_PATH} to /tmp/${CRED_PATH}"
else
  echo "entrypoint.sh: no ${CRED_PATH} found at ${REMOTE_BASE} (continuing)"
fi

# If downloaded, import them before starting n8n
if [ -f /tmp/"${WORKF_PATH}" ]; then
  echo "entrypoint.sh: importing workflows..."
  # CLI import is synchronous
  n8n import:workflow --input=/tmp/"${WORKF_PATH}" || echo "entrypoint.sh: import workflows failed (continuing)"
fi

if [ -f /tmp/"${CRED_PATH}" ]; then
  echo "entrypoint.sh: importing credentials..."
  n8n import:credentials --input=/tmp/"${CRED_PATH}" || echo "entrypoint.sh: import credentials failed (continuing)"
fi

# Start background backup script if present and executable
if [ -x /backup.sh ]; then
  echo "entrypoint.sh: starting /backup.sh in background"
  /backup.sh &   # will keep running as child process
else
  echo "entrypoint.sh: /backup.sh not found or not executable, skipping background backup"
fi

# Finally, exec n8n so it runs as PID 1 (proper signal handling)
echo "entrypoint.sh: exec n8n start --tunnel"
exec n8n start --tunnel
