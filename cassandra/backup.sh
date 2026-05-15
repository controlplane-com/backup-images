#!/usr/bin/env bash
set -euo pipefail

export HOME="${HOME:-/tmp}"

BACKUP_TYPE="${BACKUP_TYPE:-logical}"

echo "Starting Cassandra backup — type: ${BACKUP_TYPE}"

# === Common validation ===
: "${BACKUP_PROVIDER:?Missing BACKUP_PROVIDER (aws|gcp)}"
: "${BACKUP_BUCKET:?Missing BACKUP_BUCKET}"
: "${BACKUP_PREFIX:?Missing BACKUP_PREFIX}"

BACKUP_PROVIDER="$(echo "${BACKUP_PROVIDER}" | tr '[:upper:]' '[:lower:]')"
BACKUP_PREFIX="${BACKUP_PREFIX%/}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H-%M-%SZ")

upload() {
  local src="$1" dest="$2"
  if [ "${BACKUP_PROVIDER}" = "aws" ]; then
    : "${AWS_REGION:?Missing AWS_REGION}"
    aws s3 cp "${src}" "s3://${BACKUP_BUCKET}/${dest}"
  elif [ "${BACKUP_PROVIDER}" = "gcp" ]; then
    gsutil cp "${src}" "gs://${BACKUP_BUCKET}/${dest}"
  else
    echo "Unsupported BACKUP_PROVIDER: ${BACKUP_PROVIDER}" >&2
    exit 1
  fi
}

sync_dir() {
  local src="$1" dest="$2"
  if [ "${BACKUP_PROVIDER}" = "aws" ]; then
    : "${AWS_REGION:?Missing AWS_REGION}"
    aws s3 sync "${src}/" "s3://${BACKUP_BUCKET}/${dest}/"
  elif [ "${BACKUP_PROVIDER}" = "gcp" ]; then
    gsutil -m rsync -r "${src}/" "gs://${BACKUP_BUCKET}/${dest}/"
  else
    echo "Unsupported BACKUP_PROVIDER: ${BACKUP_PROVIDER}" >&2
    exit 1
  fi
}

# =============================================================================
# Logical backup — cqlsh COPY TO, run from a standalone cron workload
# =============================================================================
if [ "${BACKUP_TYPE}" = "logical" ]; then
  : "${CASSANDRA_HOST:?Missing CASSANDRA_HOST}"
  : "${CASSANDRA_PORT:=9042}"
  : "${CASSANDRA_USER:?Missing CASSANDRA_USER}"
  : "${CASSANDRA_PASSWORD:?Missing CASSANDRA_PASSWORD}"
  : "${CASSANDRA_KEYSPACE:?Missing CASSANDRA_KEYSPACE}"

  CQLSH_OPTS="--no-color -u ${CASSANDRA_USER} -p ${CASSANDRA_PASSWORD} ${CASSANDRA_HOST} ${CASSANDRA_PORT}"

  echo "Fetching table list for keyspace: ${CASSANDRA_KEYSPACE}"
  # Parse the ASCII-table output: skip the header/separator (first 3 lines) and the row-count footer
  TABLES=$(cqlsh ${CQLSH_OPTS} -e \
    "SELECT table_name FROM system_schema.tables WHERE keyspace_name='${CASSANDRA_KEYSPACE}';" \
    | sed -n '4,$p' | grep -v "^$" | grep -v "^(" | awk '{print $1}')

  if [ -z "${TABLES}" ]; then
    echo "ERROR: No tables found in keyspace '${CASSANDRA_KEYSPACE}'" >&2
    exit 1
  fi

  echo "Tables: ${TABLES}"
  FAILED=0

  for TABLE in ${TABLES}; do
    echo "--- Backing up ${CASSANDRA_KEYSPACE}.${TABLE} ---"
    TMP_FILE="/tmp/${TABLE}.csv"
    TMP_GZ="/tmp/${TABLE}.csv.gz"

    cqlsh ${CQLSH_OPTS} -e \
      "COPY ${CASSANDRA_KEYSPACE}.${TABLE} TO '${TMP_FILE}' WITH HEADER=true;" \
      || { echo "WARN: Export failed for ${TABLE}"; FAILED=$((FAILED + 1)); continue; }

    gzip -c "${TMP_FILE}" > "${TMP_GZ}"
    rm -f "${TMP_FILE}"

    DEST="${BACKUP_PREFIX}/${TIMESTAMP}/${CASSANDRA_KEYSPACE}/${TABLE}.csv.gz"
    upload "${TMP_GZ}" "${DEST}"
    rm -f "${TMP_GZ}"

    echo "Stored: ${BACKUP_PROVIDER}://${BACKUP_BUCKET}/${DEST}"
  done

  if [ "${FAILED}" -gt 0 ]; then
    echo "ERROR: ${FAILED} table(s) failed to export." >&2
    exit 1
  fi

  echo "Logical backup complete. Timestamp: ${TIMESTAMP}"

# =============================================================================
# Physical backup — nodetool snapshot + cloud sync, run as a sidecar
# =============================================================================
elif [ "${BACKUP_TYPE}" = "physical" ]; then
  : "${CASSANDRA_JMX_PASSWORD:?Missing CASSANDRA_JMX_PASSWORD}"

  TAG="backup-${TIMESTAMP}"
  SNAPSHOT_BASE="/var/lib/cassandra/data"
  HOSTNAME_SHORT=$(hostname -s)

  echo "Creating snapshot: ${TAG}"
  nodetool -u cassandra -pw "${CASSANDRA_JMX_PASSWORD}" snapshot -t "${TAG}"

  echo "Uploading snapshot files to ${BACKUP_PROVIDER}://${BACKUP_BUCKET}/${BACKUP_PREFIX}/${TIMESTAMP}/${HOSTNAME_SHORT}/"
  FAILED=0

  while IFS= read -r SNAP_DIR; do
    REL_PATH="${SNAP_DIR#${SNAPSHOT_BASE}/}"
    DEST="${BACKUP_PREFIX}/${TIMESTAMP}/${HOSTNAME_SHORT}/${REL_PATH}"
    sync_dir "${SNAP_DIR}" "${DEST}" \
      || { echo "WARN: Sync failed for ${SNAP_DIR}"; FAILED=$((FAILED + 1)); }
  done < <(find "${SNAPSHOT_BASE}" -path "*/snapshots/${TAG}" -type d)

  echo "Clearing snapshot: ${TAG}"
  nodetool -u cassandra -pw "${CASSANDRA_JMX_PASSWORD}" clearsnapshot -t "${TAG}"

  if [ "${FAILED}" -gt 0 ]; then
    echo "ERROR: ${FAILED} snapshot dir(s) failed to sync." >&2
    exit 1
  fi

  echo "Physical backup complete. Tag: ${TAG}, Timestamp: ${TIMESTAMP}"

else
  echo "Unsupported BACKUP_TYPE: '${BACKUP_TYPE}' — use 'logical' or 'physical'" >&2
  exit 1
fi
