#!/usr/bin/env bash
set -euo pipefail

export HOME="${HOME:-/tmp}"

echo "Starting Postgres backup job"

# Validate required Postgres variables
: "${PG_HOST:?Missing PG_HOST}"
: "${PG_PORT:?Missing PG_PORT}"
: "${PG_USER:=root}"
: "${PG_PASSWORD:?Missing PG_PASSWORD}"

# Validate backup variables
: "${BACKUP_PROVIDER:?Missing BACKUP_PROVIDER (aws|gcp)}"
: "${BACKUP_BUCKET:?Missing BACKUP_BUCKET}"
: "${BACKUP_PREFIX:?Missing BACKUP_PREFIX}"

# Normalize provider
BACKUP_PROVIDER="$(echo "${BACKUP_PROVIDER}" | tr '[:upper:]' '[:lower:]')"

# Sanitize BACKUP_PREFIX (remove trailing slash)
BACKUP_PREFIX="${BACKUP_PREFIX%/}"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H-%M-%SZ")
FILENAME="postgres-${TIMESTAMP}.sql.gz"

export PGPASSWORD="${PG_PASSWORD}"

echo "Running pg_dumpall against ${PG_HOST}:${PG_PORT}" >&2

if [ "${BACKUP_PROVIDER}" = "aws" ]; then
  : "${AWS_REGION:?Missing AWS_REGION}"
  export AWS_REGION="${AWS_REGION}"

  pg_dumpall \
    --host="${PG_HOST}" \
    --port="${PG_PORT}" \
    --username="${PG_USER}" \
  | gzip \
  | aws s3 cp - "s3://${BACKUP_BUCKET}/${BACKUP_PREFIX}/${FILENAME}"

elif [ "${BACKUP_PROVIDER}" = "gcp" ]; then
  pg_dumpall \
    --host="${PG_HOST}" \
    --port="${PG_PORT}" \
    --username="${PG_USER}" \
  | gzip \
  | gsutil cp - "gs://${BACKUP_BUCKET}/${BACKUP_PREFIX}/${FILENAME}"

else
  echo "Unsupported BACKUP_PROVIDER: ${BACKUP_PROVIDER}" >&2
  exit 1
fi

unset PGPASSWORD

echo "Backup completed successfully"
echo "Stored at ${BACKUP_PROVIDER}://${BACKUP_BUCKET}/${BACKUP_PREFIX}/${FILENAME}"