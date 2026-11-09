#!/bin/bash
set -eux -o pipefail

: "${BUCKET_NAME?}" "${AWS_ACCESS_KEY_ID?}" "${AWS_SECRET_ACCESS_KEY?}"
: "${ARCHIVE_NAME:?Set ARCHIVE_NAME}"

if ! test -f "${ARCHIVE_NAME}"; then
  echo 'ERROR: archive not found'
  exit 1
fi

# Backup existing remote archive before uploading the new one
backup_source="s3://${BUCKET_NAME}/${ARCHIVE_NAME}"
backup_destination="s3://${BUCKET_NAME}/${ARCHIVE_NAME}.backup-$(date -u +%Y%m%d)"
# Don't fail if there is no existing archive to backup
time aws s3 cp "${backup_source}" "${backup_destination}" --no-progress --copy-props none || true

# Upload new archive
time aws s3 cp "${ARCHIVE_NAME}" "s3://${BUCKET_NAME}" --no-progress

# Cleanup old backups
cutoff_date="$(date -u -d '15 days ago' +%Y%m%d || date -v-15d +%Y%m%d)"
old_backups="$(aws s3api list-objects-v2 --bucket "${BUCKET_NAME}" --output json \
  | jq -r --arg cutoff "${cutoff_date}" '.Contents[]?.Key | select(split(".backup-")[-1] < $cutoff)')"
while IFS= read -r backup; do
  [[ -z "${backup}" ]] && continue
  echo "Deleting older backup ${backup}"
  aws s3 rm "s3://${BUCKET_NAME}/${backup}"
done <<< "${old_backups}"

# List remote files
aws s3 ls "${BUCKET_NAME}" --human-readable --summarize
