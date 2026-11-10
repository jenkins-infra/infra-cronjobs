#!/bin/bash
set -eux -o pipefail

: "${ARCHIVE_NAME:?Set ARCHIVE_NAME}"
# All the following STORAGE_* (upper case) variables are needed by get-fileshare-signed-url.sh
: "${STORAGE_NAME:?Set STORAGE_NAME}"
: "${STORAGE_FILESHARE:?Set STORAGE_FILESHARE}"

if ! test -f "${ARCHIVE_NAME}"; then
  echo 'ERROR: archive not found'
  exit 1
fi

export STORAGE_NAME STORAGE_FILESHARE
# Short lived token
export STORAGE_DURATION_IN_MINUTE=2
# Both read and write are needed
export STORAGE_PERMISSIONS=dlrw

# Disable debug to ensure token isn't printed in the output
set +x
fileshare_signed_url="$(get-fileshare-signed-url.sh)"
url_without_token="${fileshare_signed_url%\?*}"
token="${fileshare_signed_url#*\?}"

azcopy_options=(
  --skip-version-check        # Do not check for new azcopy versions
  --log-level=ERROR           # Do not write too much logs (I/O...)
  --overwrite="ifSourceNewer" # Upload if and only if the archive is newer
)

# Backup existing remote archive before uploading the new one
backup_source="${url_without_token}${ARCHIVE_NAME}?${token}"
backup_destination="${url_without_token}${ARCHIVE_NAME}.backup"
backup_date_marker="${ARCHIVE_NAME}.backup_date"
date -u "+%Y-%m-%dZ%H:%M" > "${backup_date_marker}"
time azcopy copy "${backup_source}" "${backup_destination}" "${azcopy_options[@]}" \
  && azcopy copy "${backup_date_marker}" "${url_without_token}" "${azcopy_options[@]}" \
  && echo "INFO: backup of ${url_without_token}${ARCHIVE_NAME} OK" \
  || echo "WARNING: coulnd't backup ${ARCHIVE_NAME} from ${url_without_token} (new archive name?)"

# Upload new archive
echo "INFO: Uploading ${ARCHIVE_NAME} to ${url_without_token}"
azcopy copy "${ARCHIVE_NAME}" "${fileshare_signed_url}" "${azcopy_options[@]}"

# List remote files
azcopy list "${fileshare_signed_url}" --running-tally
