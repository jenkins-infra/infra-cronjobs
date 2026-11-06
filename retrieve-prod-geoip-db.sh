#!/bin/bash
################################################################################################################
# This script retrieves the current GeoIP database from our production (Azure Storage).
# It fails if there is a missing requirement or if azcopy cannot list the storage content.
# It does NOT fail if there are no data retrieved from the remote storage.
################################################################################################################

set -eu -o pipefail

geoip_db_dir=${GEOIP_DB_DIR?'ERROR: environment variable GEOIP_DB_DIR must be set.'}
STORAGE_NAME=${STORAGE_NAME:?'ERROR: environment variable STORAGE_NAME must be set.'}
STORAGE_FILESHARE=${STORAGE_FILESHARE:?'ERROR: environment variable STORAGE_FILESHARE must be set.'}

mkdir -p "${geoip_db_dir}"

# All the following STORAGE_* (upper case) variables are needed by get-fileshare-signed-url.sh
STORAGE_NAME=${STORAGE_NAME:?'ERROR: environment variable STORAGE_NAME must be set.'}
STORAGE_FILESHARE=${STORAGE_FILESHARE:?'ERROR: environment variable STORAGE_FILESHARE must be set.'}
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

echo "[INFO] Verifying azcopy can read the remote storage (${urlWithoutToken})..."
# See https://github.com/Azure/azure-storage-azcopy/issues/3024 for the piped prefix workaround
: | azcopy list "${fileShareSignedUrl}"\
  --skip-version-check `# Do not check for new azcopy versions (we have updatecli + puppet for this)` \
  --log-level=ERROR `# Do not write too much logs (I/O...)` \
|| \
  { cat "${HOME}/.azcopy/*"; exit 1; } # Dump the azcopy logs in case of error
unset fileShareSignedUrl

# Assuming all data is at the root
sourceUrl="${urlWithoutToken}*"
echo "[INFO] Copying data from: ${urlWithoutToken}..."
# See https://github.com/Azure/azure-storage-azcopy/issues/3024 for the piped prefix workaround
: | azcopy copy \
  "${sourceUrl}?${token}" "${geoip_db_dir}"/ \
  --skip-version-check `# Do not check for new azcopy versions (we have updatecli + puppet for this)` \
  --log-level=ERROR `# Do not write too much logs (I/O...)` \
|| true # Do not fail the copy: we can list the remote storage but copy went wrong: the DB will be redeployed.

echo '[INFO] Retrieved data from production (may be empty):'
echo

ls -ltra "${geoip_db_dir}"/

exit 0
