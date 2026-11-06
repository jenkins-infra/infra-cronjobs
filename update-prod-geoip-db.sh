#!/bin/bash
################################################################################################################
# This script deploys the GeoIP database in $GEOIP_DB_DIR to production (Azure Storage).
# It fails if there is a missing requirement or hard error (network, etc.).
# It only deploys if the $GEOIP_DB_UPDATED_REPORT file exists and then removes it.
# Note: it does NOT fail if there are no deployment.
################################################################################################################

set -eu -o pipefail

geoip_db_dir="$(cd "${GEOIP_DB_DIR?'ERROR: environment variable GEOIP_DB_DIR must be set.'}" && pwd -P)" \
  || { echo "ERROR: no directory at the value provided by GEOIP_DB_DIR (${GEOIP_DB_DIR})"; exit 1; }
geoip_db_updated_report="${GEOIP_DB_UPDATED_REPORT?'ERROR: environment variable GEOIP_DB_UPDATED_REPORT must be set.'}"

# All the following STORAGE_* (upper case) variables are needed by get-fileshare-signed-url.sh
STORAGE_NAME=${STORAGE_NAME:?'ERROR: environment variable STORAGE_NAME must be set.'}
STORAGE_FILESHARE=${STORAGE_FILESHARE:?'ERROR: environment variable STORAGE_FILESHARE must be set.'}
export STORAGE_NAME STORAGE_FILESHARE
# Short lived token
export STORAGE_DURATION_IN_MINUTE=2
# Both read and write are needed
export STORAGE_PERMISSIONS=dlrw

if test -f "${geoip_db_updated_report}"
then
  echo "[INFO] GeoIP DB has been updated: deploying to production and restarting services"

  # Disable debug to ensure token isn't printed in the output
  set +x
  fileShareSignedUrl="$(get-fileshare-signed-url.sh)"
  urlWithoutToken="${fileShareSignedUrl%\?*}"

  # Assuming all data is at the root
  echo "INFO: Copying to: ${urlWithoutToken}"

  # See https://github.com/Azure/azure-storage-azcopy/issues/3024 for the piped prefix workaround
  : | azcopy copy \
    "${geoip_db_dir}/*" "${fileShareSignedUrl}" \
    --skip-version-check `# Do not check for new azcopy versions (we have updatecli + puppet for this)` \
    --log-level=ERROR `# Do not write too much logs (I/O...)` \
    --overwrite="ifSourceNewer" `# Upload if and only if the updategeoip as updated the files` \
  || \
    { cat "${HOME}/.azcopy/*"; exit 1; }   # Dump the logs in case of error during azcopy copy
  unset fileShareSignedUrl

  echo '[INFO]: restarting service "updates.jenkins.io"...'
  # TODO: track namespace and deployment name with updatecli from https://github.com/jenkins-infra/kubernetes-management/
  kubectl --kubeconfig="${KUBECONFIG_UPDATESJENKINSIO}" --namespace=updates-jenkins-io rollout status --watch deployment updates-jenkins-io-content-mirrorbits

  # TODO: track namespace and deployment name with updatecli from https://github.com/jenkins-infra/kubernetes-management/
  echo '[INFO]: restarting service "get.jenkins.io"...'
  kubectl --kubeconfig="${KUBECONFIG_GETJENKINSIO}" --namespace=get-jenkins-io rollout status --watch deployment get-jenkins-io-content-mirrorbits

  echo '[INFO]: all good. Cleaning up leftovers...'
  rm -f "${geoip_db_updated_report}"
else
  echo '[INFO] GeoIP DB has not been updated: no action to perform'
fi

exit 0
