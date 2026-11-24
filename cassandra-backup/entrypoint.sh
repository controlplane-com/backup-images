#!/usr/bin/env bash
set -euo pipefail

# Physical backup sidecar: write a cron.d entry and run cron in the foreground
# so the container stays alive and executes backup.sh on schedule.
# Logical backup cron: no schedule set — run backup.sh once and exit
# (Control Plane handles the cron scheduling for that case).
if [ -n "${BACKUP_SCHEDULE:-}" ]; then
  # cron starts every job with an empty environment, so backup.sh would not see
  # BACKUP_*, AWS_REGION, CASSANDRA_JMX_PASSWORD, PATH (nodetool) or the cloud
  # identity variables the platform injects. Snapshot the container environment
  # into a file only root can read, and source it in the job. Values are written
  # with `declare -p`, which quotes them safely; nothing is printed.
  ENV_FILE=/etc/cassandra-backup.env
  umask 077
  : > "${ENV_FILE}"
  chmod 600 "${ENV_FILE}"
  while IFS= read -r VAR; do
    case "${VAR}" in
      _|PWD|OLDPWD|SHLVL|BASH_*|BACKUP_SCHEDULE) continue ;;
    esac
    declare -p "${VAR}" >> "${ENV_FILE}"
  done < <(compgen -e)

  # Forward cron output to the container's stdout/stderr
  {
    echo "SHELL=/bin/bash"
    # flock -n: a run still going when the next one is due is left alone; the new one is skipped.
    echo "${BACKUP_SCHEDULE} root . ${ENV_FILE} && { flock -n -E 75 /run/cassandra-backup.lock /usr/local/bin/backup.sh; [ \$? -ne 75 ] || echo \"Backup skipped: the previous run is still going\"; } >> /proc/1/fd/1 2>> /proc/1/fd/2"
  } > /etc/cron.d/cassandra-backup
  chmod 0644 /etc/cron.d/cassandra-backup
  echo "Physical backup scheduled: ${BACKUP_SCHEDULE} (UTC)"
  exec cron -f
else
  exec /usr/local/bin/backup.sh
fi
