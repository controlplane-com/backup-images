#!/usr/bin/env bash
set -euo pipefail

export MYSQL_PWD="${MYSQL_ROOT_PASSWORD}"

# Dump the CONFIGURED database, not a hardcoded name. The mysql template passes
# MYSQL_DATABASE (the app's actual DB); a fixed `test` silently failed for every
# non-`test` database ("Unknown database 'test'", nothing written to the bucket).
: "${MYSQL_DATABASE:?MYSQL_DATABASE must be set (the database to back up)}"

TIMESTAMP="$(date -u +"%Y-%m-%dT%H-%M-%SZ")"
FILENAME="mysql-${TIMESTAMP}.sql.gz"

echo "[INFO] Starting MySQL backup of database '${MYSQL_DATABASE}' (${TIMESTAMP})"

mysqldump \
  --host="${MYSQL_HOST}" \
  --port="${MYSQL_PORT}" \
  --user=root \
  --databases "${MYSQL_DATABASE}" \
  --single-transaction \
  --set-gtid-purged=OFF \
  --column-statistics=0 \
  > /tmp/dump.sql

gzip /tmp/dump.sql

if [ "${BACKUP_PROVIDER}" = "gcp" ]; then
  gsutil cp /tmp/dump.sql.gz \
    "gs://${BACKUP_BUCKET}/${BACKUP_PREFIX}/${FILENAME}"

elif [ "${BACKUP_PROVIDER}" = "aws" ]; then
  aws s3 cp /tmp/dump.sql.gz \
    "s3://${BACKUP_BUCKET}/${BACKUP_PREFIX}/${FILENAME}"

else
  echo "[ERROR] Unsupported BACKUP_PROVIDER: ${BACKUP_PROVIDER}"
  exit 1
fi

echo "[INFO] Backup completed: ${FILENAME}"