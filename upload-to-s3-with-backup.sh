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
backup_destination="s3://${BUCKET_NAME}/${ARCHIVE_NAME}.backup"
backup_date_marker="${ARCHIVE_NAME}.backup_date"
date -u "+%Y-%m-%dZ%H:%M" > "${backup_date_marker}"
time aws s3 cp "${backup_source}" "${backup_destination}" --no-progress --copy-props none \
  && aws s3 cp "${backup_date_marker}" "s3://${BUCKET_NAME}" --no-progress \
  || echo "WARNING: coulnd't backup ${ARCHIVE_NAME} from ${BUCKET_NAME} (new archive name?)"

# Upload new archive
time aws s3 cp "${ARCHIVE_NAME}" "s3://${BUCKET_NAME}" --no-progress

# List remote files
aws s3 ls "${BUCKET_NAME}" --human-readable --summarize
