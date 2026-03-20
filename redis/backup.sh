#!/usr/bin/env bash
set -euo pipefail

REDIS_HOST="${REDIS_HOST}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"
NUM_PRIMARIES="${NUM_PRIMARIES:-}"
REDIS_WORKLOAD_NAME="${REDIS_WORKLOAD_NAME:-}"
CPLN_GVC="${CPLN_GVC:-}"
CPLN_LOCATION="${CPLN_LOCATION:-}"

TIMESTAMP="$(date -u +"%Y-%m-%dT%H-%M-%SZ")"

echo "[INFO] Starting Redis backup (${TIMESTAMP})"

AUTH_ARGS=()
if [ -n "${REDIS_PASSWORD}" ]; then
  AUTH_ARGS=(--pass "${REDIS_PASSWORD}")
fi

upload() {
  local src="$1"
  local dest_filename="$2"
  if [ "${BACKUP_PROVIDER}" = "gcp" ]; then
    gsutil cp "${src}" "gs://${BACKUP_BUCKET}/${BACKUP_PREFIX}/${dest_filename}"
  elif [ "${BACKUP_PROVIDER}" = "aws" ]; then
    aws s3 cp "${src}" "s3://${BACKUP_BUCKET}/${BACKUP_PREFIX}/${dest_filename}"
  else
    echo "[ERROR] Unsupported BACKUP_PROVIDER: ${BACKUP_PROVIDER}"
    exit 1
  fi
}

echo "[DEBUG] CLUSTER INFO raw output:"
redis-cli \
  -h "${REDIS_HOST}" \
  -p "${REDIS_PORT}" \
  "${AUTH_ARGS[@]}" \
  CLUSTER INFO || true

CLUSTER_SLOTS=$(redis-cli \
  -h "${REDIS_HOST}" \
  -p "${REDIS_PORT}" \
  "${AUTH_ARGS[@]}" \
  CLUSTER INFO 2>/dev/null \
  | grep "^cluster_slots_assigned:" | tr -d '[:space:]' | cut -d: -f2 || echo "0")

echo "[DEBUG] CLUSTER_SLOTS=${CLUSTER_SLOTS}"

if [ "${CLUSTER_SLOTS:-0}" -gt 0 ]; then
  echo "[INFO] Cluster mode detected — backing up all master nodes"

  if [ -z "${NUM_PRIMARIES}" ]; then
    echo "[ERROR] NUM_PRIMARIES must be set for cluster mode"
    exit 1
  fi

  if [ -z "${REDIS_WORKLOAD_NAME}" ] || [ -z "${CPLN_GVC}" ] || [ -z "${CPLN_LOCATION}" ]; then
    echo "[ERROR] REDIS_WORKLOAD_NAME, CPLN_GVC, and CPLN_LOCATION must be set for cluster mode"
    exit 1
  fi

  LOCATION="${CPLN_LOCATION##*/}"
  TOTAL_NODES=$(( NUM_PRIMARIES * 2 ))
  BACKED_UP=0

  echo "[INFO] Scanning ${TOTAL_NODES} nodes for masters (pattern: replica-{0..$(( TOTAL_NODES - 1 ))}.${REDIS_WORKLOAD_NAME}.${LOCATION}.${CPLN_GVC}.cpln.local)"

  for i in $(seq 0 $(( TOTAL_NODES - 1 ))); do
    NODE_HOST="replica-${i}.${REDIS_WORKLOAD_NAME}.${LOCATION}.${CPLN_GVC}.cpln.local"

    ROLE=$(redis-cli \
      -h "${NODE_HOST}" \
      -p "${REDIS_PORT}" \
      "${AUTH_ARGS[@]}" \
      INFO replication 2>/dev/null \
      | grep "^role:" | tr -d '[:space:]' | cut -d: -f2 || echo "unknown")

    if [ "${ROLE}" != "master" ]; then
      echo "[INFO] Node ${i} is ${ROLE}, skipping"
      continue
    fi

    FILENAME="redis-${TIMESTAMP}-node-${i}.rdb.gz"
    echo "[INFO] Dumping master node ${i}: ${NODE_HOST}:${REDIS_PORT}"

    redis-cli \
      -h "${NODE_HOST}" \
      -p "${REDIS_PORT}" \
      "${AUTH_ARGS[@]}" \
      --rdb "/tmp/dump-${i}.rdb"

    gzip "/tmp/dump-${i}.rdb"
    upload "/tmp/dump-${i}.rdb.gz" "${FILENAME}"
    echo "[INFO] Backup completed: ${FILENAME}"
    BACKED_UP=$(( BACKED_UP + 1 ))
  done

  echo "[INFO] Cluster backup complete — ${BACKED_UP}/${NUM_PRIMARIES} master nodes backed up"

else
  echo "[INFO] Standalone mode — backing up single node"
  FILENAME="redis-${TIMESTAMP}.rdb.gz"

  redis-cli \
    -h "${REDIS_HOST}" \
    -p "${REDIS_PORT}" \
    "${AUTH_ARGS[@]}" \
    --rdb /tmp/dump.rdb

  gzip /tmp/dump.rdb
  mv /tmp/dump.rdb.gz "/tmp/${FILENAME}"
  upload "/tmp/${FILENAME}" "${FILENAME}"
  echo "[INFO] Backup completed: ${FILENAME}"
fi
