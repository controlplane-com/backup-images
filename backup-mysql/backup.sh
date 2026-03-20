#!/usr/bin/env bash
set -euo pipefail

export MYSQL_PWD="${MYSQL_ROOT_PASSWORD}"

TIMESTAMP="$(date -u +"%Y-%m-%dT%H-%M-%SZ")"
FILENAME="mysql-${TIMESTAMP}.sql.gz"

echo "[INFO] Starting MySQL backup (${TIMESTAMP})"

mysqldump \
  --host="${MYSQL_HOST}" \
  --port="${MYSQL_PORT}" \
  --user=root \
  --databases test \
  --single-transaction \
  --set-gtid-purged=OFF \
  --column-statistics=0 \
  > /tmp/test.sql

gzip /tmp/test.sql

if [ "${BACKUP_PROVIDER}" = "gcp" ]; then
  gsutil cp /tmp/test.sql.gz \
    "gs://${BACKUP_BUCKET}/${BACKUP_PREFIX}/${FILENAME}"

elif [ "${BACKUP_PROVIDER}" = "aws" ]; then
  aws s3 cp /tmp/test.sql.gz \
    "s3://${BACKUP_BUCKET}/${BACKUP_PREFIX}/${FILENAME}"

else
  echo "[ERROR] Unsupported BACKUP_PROVIDER: ${BACKUP_PROVIDER}"
  exit 1
fi

echo "[INFO] Backup completed: ${FILENAME}"