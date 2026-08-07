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
elif [ "${BACKUP_PROVIDER}" = "gcp" ]; then
  # BR defaults --send-credentials-to-tikv=true, which requires an explicit
  # --gcs.credentials_file. On Control Plane the credentials come from the GCP
  # metadata emulation and there is no key file, so BR exits 1 immediately —
  # fast enough that the job looks like a silent failure.
  #
  # With this false, each TiKV resolves GCS credentials itself. That only works
  # from TiDB v8.5.7, where TiKV enables the `gcp_v2` external storage backend
  # by default (gcp_v2 supports ADC / the metadata server; the legacy backend
  # did not, and failed SST uploads with "I/O permission denied").
  BR_EXTRA_FLAGS="--send-credentials-to-tikv=false"
fi

br backup full \
  --pd="${TIDB_PD_ADDR}" \
  --storage="${STORAGE}" \
  ${BR_EXTRA_FLAGS} \
  --log-file=/dev/stdout

echo "[INFO] Backup completed: ${BACKUP_PATH}"
