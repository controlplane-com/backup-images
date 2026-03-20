#!/usr/bin/env bash
set -euo pipefail

TIMESTAMP="$(date -u +"%Y-%m-%dT%H-%M-%SZ")"
FILENAME="mongo-${TIMESTAMP}.archive.gz"
DUMP_DIR="/tmp/mongodump-${TIMESTAMP}"

echo "[INFO] Starting MongoDB backup (${TIMESTAMP})"

# Build the connection URI. If MONGO_URI is set, use it directly;
# otherwise construct one from individual variables.
if [ -n "${MONGO_URI:-}" ]; then
  CONNECTION_URI="${MONGO_URI}"
else
  CONNECTION_URI="mongodb://${MONGO_USER:-}:${MONGO_PASSWORD:-}@${MONGO_HOST}:${MONGO_PORT:-27017}"
fi

# Dump: use --archive for a single-file output, gzip compressed.
mongodump \
  --uri="${CONNECTION_URI}" \
  ${MONGO_DB:+--db="${MONGO_DB}"} \
  --archive="${DUMP_DIR}.archive" \
  --gzip

# Rename to timestamped filename for upload.
mv "${DUMP_DIR}.archive" "/tmp/${FILENAME}"

if [ "${BACKUP_PROVIDER}" = "gcp" ]; then
  gsutil cp "/tmp/${FILENAME}" \
    "gs://${BACKUP_BUCKET}/${BACKUP_PREFIX}/${FILENAME}"

elif [ "${BACKUP_PROVIDER}" = "aws" ]; then
  aws s3 cp "/tmp/${FILENAME}" \
    "s3://${BACKUP_BUCKET}/${BACKUP_PREFIX}/${FILENAME}"

else
  echo "[ERROR] Unsupported BACKUP_PROVIDER: ${BACKUP_PROVIDER}"
  exit 1
fi

rm -f "/tmp/${FILENAME}"

echo "[INFO] Backup completed: ${FILENAME}"
