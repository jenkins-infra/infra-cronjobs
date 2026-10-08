#!/bin/bash

set -eux -o pipefail

geoipupdate_db_dir="$(cd "${GEOIPUPDATE_DB_DIR?'ERROR: environment variable GEOIPUPDATE_DB_DIR must be set.'}" && pwd -P)" \
  || { echo "ERROR: no directory at the value provided by GEOIPUPDATE_DB_DIR (${GEOIPUPDATE_DB_DIR})"; exit 1; }
geoipupdate_json_report="${GEOIPUPDATE_JSON_REPORT?'ERROR: environment variable GEOIPUPDATE_JSON_REPORT must be set.'}"
test -f "${geoipupdate_json_report}" \
  || { echo "ERROR: no file found at the value provided by GEOIPUPDATE_JSON_REPORT (${GEOIPUPDATE_JSON_REPORT})"; exit 1; }

# All the following STORAGE_* (upper case) variables are needed by get-fileshare-signed-url.sh
STORAGE_NAME=${STORAGE_NAME:?'ERROR: environment variable STORAGE_NAME must be set.'}
STORAGE_FILESHARE=${STORAGE_FILESHARE:?'ERROR: environment variable STORAGE_FILESHARE must be set.'}
export STORAGE_NAME STORAGE_FILESHARE
# Short lived token
export STORAGE_DURATION_IN_MINUTE=2
# Both read and write are needed
export STORAGE_PERMISSIONS=dlrw

# > /dev/null to avoid multiple true in output but keep errors output
if jq -e '.[] | select(.old_hash != .new_hash)' "${geoipupdate_json_report}" > /dev/null
then
  ####
  # Deploy DB files
  ####

  # Disable debug to ensure token isn't printed in the output
  set +x
  fileShareSignedUrl="$(get-fileshare-signed-url.sh)"
  urlWithoutToken="${fileShareSignedUrl%\?*}"

  # Assuming all data is at the root
  echo "INFO: Copying to: ${urlWithoutToken}"

  # See https://github.com/Azure/azure-storage-azcopy/issues/3024 for the piped prefix workaround
  : | azcopy copy \
    "${geoipupdate_db_dir}/*" "${fileShareSignedUrl}" \
    --skip-version-check `# Do not check for new azcopy versions (we have updatecli + puppet for this)` \
    --log-level=ERROR `# Do not write too much logs (I/O...)` \
    --overwrite="ifSourceNewer" `# Upload if and only if the updategeoip as updated the files` \
  || \
    { cat "${HOME}/.azcopy/*"; exit 1; }   #dump the logs in case of error during azcopy copy

  unset fileShareSignedUrl
  # Re-enable debug as no more token used
  set -x

  ####
  # Then restart services to ensure they load the new DB
  ####
  for mirrorbits_webservice in get.jenkins.io updates.jenkins.io
  do
    echo "INFO: restarting service ${mirrorbits_webservice}"
    # TODO
  done
else
  echo 'INFO: GeoIP Database is up to date: no action performed'
fi
