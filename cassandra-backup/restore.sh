#!/usr/bin/env bash
set -euo pipefail

export HOME="${HOME:-/tmp}"

BACKUP_TYPE="${BACKUP_TYPE:-logical}"
: "${RESTORE_TIMESTAMP:?Missing RESTORE_TIMESTAMP — set to the backup timestamp, e.g. 2026-05-15T23-21-34Z}"

echo "Starting Cassandra restore — type: ${BACKUP_TYPE}, timestamp: ${RESTORE_TIMESTAMP}"

# === Common validation ===
: "${BACKUP_PROVIDER:?Missing BACKUP_PROVIDER (aws|gcp)}"
: "${BACKUP_BUCKET:?Missing BACKUP_BUCKET}"
: "${BACKUP_PREFIX:?Missing BACKUP_PREFIX}"

BACKUP_PROVIDER="$(echo "${BACKUP_PROVIDER}" | tr '[:upper:]' '[:lower:]')"
BACKUP_PREFIX="${BACKUP_PREFIX%/}"
RESTORE_TMP="/var/lib/cassandra/restore-${RESTORE_TIMESTAMP}"

download() {
  local src="$1" dest="$2"
  mkdir -p "${dest}"
  if [ "${BACKUP_PROVIDER}" = "aws" ]; then
    : "${AWS_REGION:?Missing AWS_REGION}"
    aws s3 sync "${src}/" "${dest}/"
  elif [ "${BACKUP_PROVIDER}" = "gcp" ]; then
    gsutil -m rsync -r "${src}/" "${dest}/"
  else
    echo "Unsupported BACKUP_PROVIDER: ${BACKUP_PROVIDER}" >&2
    exit 1
  fi
}

# =============================================================================
# Logical restore — download CSVs from S3, COPY FROM via cqlsh
# =============================================================================
if [ "${BACKUP_TYPE}" = "logical" ]; then
  : "${CASSANDRA_HOST:?Missing CASSANDRA_HOST}"
  : "${CASSANDRA_PORT:=9042}"
  : "${CASSANDRA_USER:?Missing CASSANDRA_USER}"
  : "${CASSANDRA_PASSWORD:?Missing CASSANDRA_PASSWORD}"
  : "${CASSANDRA_KEYSPACE:?Missing CASSANDRA_KEYSPACE}"

  CQLSH_OPTS="--no-color -u ${CASSANDRA_USER} -p ${CASSANDRA_PASSWORD} ${CASSANDRA_HOST} ${CASSANDRA_PORT}"
  S3_PATH="${BACKUP_BUCKET}/${BACKUP_PREFIX}/${RESTORE_TIMESTAMP}/${CASSANDRA_KEYSPACE}"

  echo "Downloading from ${BACKUP_PROVIDER}://${S3_PATH}"
  if [ "${BACKUP_PROVIDER}" = "aws" ]; then
    download "s3://${S3_PATH}" "${RESTORE_TMP}"
  else
    download "gs://${S3_PATH}" "${RESTORE_TMP}"
  fi

  FAILED=0
  for GZ_FILE in "${RESTORE_TMP}"/*.csv.gz; do
    [ -f "${GZ_FILE}" ] || { echo "No backup files found in ${RESTORE_TMP}"; exit 1; }
    TABLE=$(basename "${GZ_FILE}" .csv.gz)
    CSV_FILE="${RESTORE_TMP}/${TABLE}.csv"

    echo "--- Restoring ${CASSANDRA_KEYSPACE}.${TABLE} ---"
    gunzip -c "${GZ_FILE}" > "${CSV_FILE}"

    cqlsh ${CQLSH_OPTS} -e \
      "COPY ${CASSANDRA_KEYSPACE}.${TABLE} FROM '${CSV_FILE}' WITH HEADER=true;" \
      || { echo "WARN: Restore failed for ${TABLE}"; FAILED=$((FAILED + 1)); }

    rm -f "${CSV_FILE}"
  done

  rm -rf "${RESTORE_TMP}"

  if [ "${FAILED}" -gt 0 ]; then
    echo "ERROR: ${FAILED} table(s) failed to restore." >&2
    exit 1
  fi

  echo "Logical restore complete."

# =============================================================================
# Physical restore — download SSTables from S3, copy to data dir, nodetool refresh
# =============================================================================
elif [ "${BACKUP_TYPE}" = "physical" ]; then
  : "${CASSANDRA_JMX_PASSWORD:?Missing CASSANDRA_JMX_PASSWORD}"

  HOSTNAME_SHORT=$(hostname -s)
  S3_PATH="${BACKUP_BUCKET}/${BACKUP_PREFIX}/${RESTORE_TIMESTAMP}/${HOSTNAME_SHORT}"

  echo "Downloading from ${BACKUP_PROVIDER}://${S3_PATH}"
  if [ "${BACKUP_PROVIDER}" = "aws" ]; then
    download "s3://${S3_PATH}" "${RESTORE_TMP}"
  else
    download "gs://${S3_PATH}" "${RESTORE_TMP}"
  fi

  # S3 structure: {tmp}/{keyspace}/{table-uuid}/snapshots/{tag}/files
  # nodetool import reads directly from the snapshot directory — no manual copy needed
  FAILED=0

  while IFS= read -r SNAP_DIR; do
    REL="${SNAP_DIR#${RESTORE_TMP}/}"           # keyspace/table-uuid/snapshots/tag
    TABLE_UUID_PATH="${REL%/snapshots/*}"        # keyspace/table-uuid
    KEYSPACE=$(dirname "${TABLE_UUID_PATH}")     # keyspace
    TABLE_UUID_DIR=$(basename "${TABLE_UUID_PATH}") # table-uuid

    # Extract table name by stripping the trailing -<32 hex chars> UUID suffix
    TABLE_NAME=$(echo "${TABLE_UUID_DIR}" | sed 's/-[0-9a-f]\{32\}$//')

    echo "--- Importing ${KEYSPACE}.${TABLE_NAME} ---"
    chown -R cassandra:cassandra "${SNAP_DIR}" 2>/dev/null || true
    nodetool -u cassandra -pw "${CASSANDRA_JMX_PASSWORD}" import "${KEYSPACE}" "${TABLE_NAME}" "${SNAP_DIR}" \
      || { echo "WARN: nodetool import failed for ${KEYSPACE}.${TABLE_NAME}"; FAILED=$((FAILED + 1)); }
  done < <(find "${RESTORE_TMP}" -mindepth 4 -maxdepth 4 -type d)

  rm -rf "${RESTORE_TMP}"

  if [ "${FAILED}" -gt 0 ]; then
    echo "ERROR: ${FAILED} table(s) failed to refresh." >&2
    exit 1
  fi

  echo "Physical restore complete."

else
  echo "Unsupported BACKUP_TYPE: '${BACKUP_TYPE}' — use 'logical' or 'physical'" >&2
  exit 1
fi
