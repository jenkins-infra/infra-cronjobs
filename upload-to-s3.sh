#!/bin/bash
set -eux -o pipefail

: "${BUCKET_NAME?}" "${AWS_ACCESS_KEY_ID?}" "${AWS_SECRET_ACCESS_KEY?}"
: "${ARCHIVE_NAME:?Set ARCHIVE_NAME}"

if ! test -f "${ARCHIVE_NAME}"; then
  echo 'ERROR: archive not found'
  exit 1
fi

# Upload new archive
time aws s3 cp "${ARCHIVE_NAME}" "s3://${BUCKET_NAME}" --no-progress

# List remote files
aws s3 ls "${BUCKET_NAME}" --human-readable --summarize
