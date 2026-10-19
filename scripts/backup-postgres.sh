#!/usr/bin/env bash
# Nightly Postgres backup to S3 with retention and Telegram alert on failure.
# Cron (installed by bootstrap-vm.sh): 0 2 * * * /opt/nanhr/scripts/backup-postgres.sh
set -euo pipefail

cd "$(dirname "$0")/../deploy"
set -a; source .env; set +a

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
FILE="/tmp/nanhr-${STAMP}.sql.gz"

notify() {
  [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]] || return 0
  curl -fsS "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" -d text="$1" >/dev/null || true
}
trap 'notify "NAN HR backup FAILED on $(hostname) at ${STAMP}"; rm -f "$FILE"' ERR

docker compose exec -T db pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner | gzip > "$FILE"
aws s3 cp "$FILE" "${S3_BUCKET}/${STAMP}.sql.gz" --only-show-errors
rm -f "$FILE"

# Delete backups older than the retention window.
CUTOFF="$(date -u -d "-${BACKUP_RETENTION_DAYS:-14} days" +%Y%m%dT%H%M%SZ)"
aws s3 ls "${S3_BUCKET}/" | awk '{print $4}' | while read -r key; do
  if [[ "${key%.sql.gz}" < "$CUTOFF" ]]; then
    aws s3 rm "${S3_BUCKET}/${key}" --only-show-errors
  fi
done

echo "Backup uploaded: ${S3_BUCKET}/${STAMP}.sql.gz"
