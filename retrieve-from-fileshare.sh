#!/bin/bash
set -eux -o pipefail

: "${SOURCE_PATH:?Set SOURCE_PATH}"
: "${DESTINATION_PATH:?Set DESTINATION_PATH}"
# All the following STORAGE_* (upper case) variables are needed by get-fileshare-signed-url.sh
: "${STORAGE_NAME:?Set STORAGE_NAME}"
: "${STORAGE_FILESHARE:?Set STORAGE_FILESHARE}"

mkdir -p "${DESTINATION_PATH}"

export STORAGE_NAME STORAGE_FILESHARE
# Short lived token
export STORAGE_DURATION_IN_MINUTE=2
# Read only: we only retrieve files
export STORAGE_PERMISSIONS=dlr

# Disable debug to ensure token isn't printed in the output
set +x
fileShareSignedUrl="$(get-fileshare-signed-url.sh)"
urlWithoutToken="${fileShareSignedUrl%\?*}"
token="${fileShareSignedUrl#*\?}"

# Assuming all data is at the root
sourceUrl="${urlWithoutToken%/}/${SOURCE_PATH}"
echo "INFO: Copying from: ${sourceUrl}"

# See https://github.com/Azure/azure-storage-azcopy/issues/3024 for the piped prefix workaround
: | azcopy copy \
  "${sourceUrl}?${token}" "${DESTINATION_PATH}"/ \
  --skip-version-check `# Do not check for new azcopy versions (we have updatecli + puppet for this)` \
  --log-level=ERROR `# Do not write too much logs (I/O...)` \
|| \
  { cat "${HOME}/.azcopy/*"; exit 1; }   # Dump the azcopy logs in case of error

ls -ltra "${DESTINATION_PATH}"/

exit 0
