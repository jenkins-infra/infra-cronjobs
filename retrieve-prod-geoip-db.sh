#!/bin/bash

set -eux -o pipefail

geoipupdate_db_dir=${GEOIPUPDATE_DB_DIR?'ERROR: environment variable GEOIPUPDATE_DB_DIR must be set.'}
STORAGE_NAME=${STORAGE_NAME:?'ERROR: environment variable STORAGE_NAME must be set.'}
STORAGE_FILESHARE=${STORAGE_FILESHARE:?'ERROR: environment variable STORAGE_FILESHARE must be set.'}

mkdir -p "${geoipupdate_db_dir}"

# Short lived token
export STORAGE_DURATION_IN_MINUTE=2
# Read only: we only retrieve files
export STORAGE_PERMISSIONS=dlr

# Disable debug to ensure token isn't printed in the output
set +x
export STORAGE_NAME STORAGE_FILESHARE
fileShareSignedUrl="$(get-fileshare-signed-url.sh)"
urlWithoutToken="${fileShareSignedUrl%\?*}"
token="${fileShareSignedUrl#*\?}"

# Assuming all data is at the root
sourceUrl="${urlWithoutToken}*"
echo "INFO: Copying from: ${sourceUrl}"

# See https://github.com/Azure/azure-storage-azcopy/issues/3024 for the piped prefix workaround
: | azcopy copy \
  "${sourceUrl}?${token}" "${geoipupdate_db_dir}"/ \
  --skip-version-check `# Do not check for new azcopy versions (we have updatecli + puppet for this)` \
  --log-level=ERROR `# Do not write too much logs (I/O...)` \
  --include-pattern='*.mmdb' `# only the mmdb GeoIP databases files` \
|| \
  { cat "${HOME}/.azcopy/*"; exit 1; }   # Dump the azcopy logs in case of error

ls -ltra "${geoipupdate_db_dir}"/

exit 0
