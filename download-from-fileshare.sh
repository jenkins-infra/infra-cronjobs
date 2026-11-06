#!/bin/bash
set -eux -o pipefail

: "${ARCHIVE_NAME:?Set ARCHIVE_NAME}"
# All the following STORAGE_* (upper case) variables are required by get-fileshare-signed-url.sh
: "${STORAGE_NAME:?Set STORAGE_NAME}"
: "${STORAGE_FILESHARE:?Set STORAGE_FILESHARE}"

export STORAGE_NAME STORAGE_FILESHARE
# Short lived token
export STORAGE_DURATION_IN_MINUTE=2
# Read only: we only retrieve files
export STORAGE_PERMISSIONS=dlr

# Disable debug to ensure token isn't printed in the output
set +x
fileshare_signed_url="$(get-fileshare-signed-url.sh)"
url_without_token="${fileshare_signed_url%\?*}"
token="${fileshare_signed_url#*\?}"

# Assuming all data is at the root
source_url="${url_without_token%/}/${ARCHIVE_NAME}"
echo "INFO: Downloading ${ARCHIVE_NAME} from ${source_url}"

azcopy copy "${source_url}?${token}" . \
  --skip-version-check `# Do not check for new azcopy versions` \
  --log-level=ERROR `# Do not write too much logs (I/O...)` \
|| { cat "${HOME}/.azcopy/*"; exit 1; }   # Dump azcopy logs in case of error

ls -ltra .
