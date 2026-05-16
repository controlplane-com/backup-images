#!/usr/bin/env bash
set -euo pipefail

# Physical backup sidecar: write a cron.d entry and run cron in the foreground
# so the container stays alive and executes backup.sh on schedule.
# Logical backup cron: no schedule set — run backup.sh once and exit
# (Control Plane handles the cron scheduling for that case).
if [ -n "${BACKUP_SCHEDULE:-}" ]; then
  # Forward cron output to the container's stdout/stderr
  echo "${BACKUP_SCHEDULE} root /usr/local/bin/backup.sh >> /proc/1/fd/1 2>> /proc/1/fd/2" \
    > /etc/cron.d/cassandra-backup
  chmod 0644 /etc/cron.d/cassandra-backup
  exec cron -f
else
  exec /usr/local/bin/backup.sh
fi
