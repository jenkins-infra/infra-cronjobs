#!/bin/bash
set -eux -o pipefail

: "${ARCHIVE_NAME:?Set ARCHIVE_NAME}"
# All the following STORAGE_* (upper case) variables are needed by get-fileshare-signed-url.sh
: "${STORAGE_NAME:?Set STORAGE_NAME}"
: "${STORAGE_FILESHARE:?Set STORAGE_FILESHARE}"

export STORAGE_NAME STORAGE_FILESHARE
# Short lived token
export STORAGE_DURATION_IN_MINUTE=2
# Both read and write are needed
export STORAGE_PERMISSIONS=dlrw

if test -f "${ARCHIVE_NAME}" && tar --list --file "${ARCHIVE_NAME}"; then
  echo 'ERROR: archive not found or bad'
  exit 1
fi

# Disable debug to ensure token isn't printed in the output
set +x
fileShareSignedUrl="$(get-fileshare-signed-url.sh)"
urlWithoutToken="${fileShareSignedUrl%\?*}"

# Assuming all data is at the root
sourceUrl="${urlWithoutToken}*"
echo "INFO: Copying to: ${sourceUrl}"

# See https://github.com/Azure/azure-storage-azcopy/issues/3024 for the piped prefix workaround
: | azcopy copy \
  "${ARCHIVE_NAME}" "${fileShareSignedUrl}" \
  --skip-version-check `# Do not check for new azcopy versions (we have updatecli + puppet for this)` \
  --log-level=ERROR `# Do not write too much logs (I/O...)` \
  --overwrite="ifSourceNewer" `# Upload if and only if the archive is newer` \
|| \
  { cat "${HOME}/.azcopy/*"; exit 1; }   #dump the logs in case of error during azcopy copy

unset fileShareSignedUrl
# Re-enable debug as no more token used
set -x
