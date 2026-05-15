#!/usr/bin/env bash
set -euo pipefail

# Physical backup sidecar: run supercronic so the container stays alive and
# executes backup.sh on schedule. Logical backup cron: no schedule set — just
# run backup.sh once and exit (Control Plane handles the cron scheduling).
if [ -n "${BACKUP_SCHEDULE:-}" ]; then
  echo "${BACKUP_SCHEDULE} /usr/local/bin/backup.sh" > /tmp/crontab
  exec supercronic /tmp/crontab
else
  exec /usr/local/bin/backup.sh
fi
