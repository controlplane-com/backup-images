#!/usr/bin/env bash
set -euo pipefail

TIMESTAMP="$(date -u +"%Y-%m-%dT%H-%M-%SZ")"
BACKUP_PATH="tidb-${TIMESTAMP}"

echo "[INFO] Starting TiDB backup (${TIMESTAMP})"
echo "[INFO] PD address: ${TIDB_PD_ADDR}"

if [ "${BACKUP_PROVIDER}" = "gcp" ]; then
  STORAGE="gcs://${BACKUP_BUCKET}/${BACKUP_PREFIX}/${BACKUP_PATH}"

elif [ "${BACKUP_PROVIDER}" = "aws" ]; then
  STORAGE="s3://${BACKUP_BUCKET}/${BACKUP_PREFIX}/${BACKUP_PATH}"

else
  echo "[ERROR] Unsupported BACKUP_PROVIDER: ${BACKUP_PROVIDER}"
  exit 1
fi

BR_EXTRA_FLAGS=""
if [ "${BACKUP_PROVIDER}" = "aws" ]; then
  BR_EXTRA_FLAGS="--s3.region=${AWS_REGION}"
fi

br backup full \
  --pd="${TIDB_PD_ADDR}" \
  --storage="${STORAGE}" \
  ${BR_EXTRA_FLAGS} \
  --log-file=/dev/stdout

echo "[INFO] Backup completed: ${BACKUP_PATH}"
