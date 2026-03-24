#!/bin/bash
set -euo pipefail

if [ "${BACKUP_PROVIDER}" = "aws" ]; then
  STORAGE="s3://${AWS_BUCKET}/${AWS_PREFIX}?AUTH=implicit&AWS_REGION=${AWS_REGION}"
elif [ "${BACKUP_PROVIDER}" = "gcp" ]; then
  STORAGE="gs://${GCP_BUCKET}/${GCP_PREFIX}?AUTH=implicit"
else
  echo "ERROR: Unknown BACKUP_PROVIDER '${BACKUP_PROVIDER}'. Must be 'aws' or 'gcp'."
  exit 1
fi

echo "Starting CockroachDB backup to ${BACKUP_PROVIDER}..."

cockroach sql \
  --insecure \
  --host="${COCKROACH_HOST}:26257" \
  --execute="BACKUP INTO '${STORAGE}' AS OF SYSTEM TIME '-10s';"

echo "Backup complete."
