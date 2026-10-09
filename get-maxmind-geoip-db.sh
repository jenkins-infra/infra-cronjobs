#!/bin/bash

set -eux -o pipefail

geoipupdate_db_dir="$(cd "${GEOIPUPDATE_DB_DIR?'ERROR: environment variable GEOIPUPDATE_DB_DIR must be set.'}" && pwd -P)" \
  || { echo "ERROR: no directory at the value provided by GEOIPUPDATE_DB_DIR (${GEOIPUPDATE_DB_DIR})"; exit 1; }
export geoipupdate_db_dir
geoipupdate_json_report="${GEOIPUPDATE_JSON_REPORT?'ERROR: environment variable GEOIPUPDATE_JSON_REPORT must be set.'}"
GEOIPUPDATE_DOCKER_IMAGE="${GEOIPUPDATE_DOCKER_IMAGE?'ERROR: environment variable GEOIPUPDATE_DOCKER_IMAGE must be set.'}"

geoipupdate_logs_dir="$(cd "$(dirname "$0")" && pwd -P)/geoipupdate_logs"
rm -rf "${geoipupdate_logs_dir}"
mkdir -p "${geoipupdate_logs_dir}"

if [ "${GEOIPUPDATE_DRYRUN:-false}" == "true" ]; then
  GEOIPUPDATE_EDITION_IDS="${GEOIPUPDATE_EDITION_IDS?'ERROR: environment variable GEOIPUPDATE_EDITION_IDS must be set.'}"
  GEOIPUPDATE_ACCOUNT_ID="${GEOIPUPDATE_ACCOUNT_ID?'ERROR: environment variable GEOIPUPDATE_ACCOUNT_ID must be set.'}"
  GEOIPUPDATE_LICENSE_KEY="${GEOIPUPDATE_LICENSE_KEY?'ERROR: environment variable GEOIPUPDATE_LICENSE_KEY must be set.'}"

  touch "${geoipupdate_json_report}" # In case it does not exist
  cat "${geoipupdate_json_report}"

  docker container run --rm \
    --volume "${geoipupdate_db_dir}:${geoipupdate_db_dir}:rw" \
    --volume "${geoipupdate_json_report}:/tmp/geoipupdate/healthcheck:rw" `# ref. $logfile at https://github.com/maxmind/geoipupdate/blob/9da00bfca4633cd388f1393b6919dc51f1bb992b/docker/entry.sh#L19` \
    --env GEOIPUPDATE_EDITION_IDS \
    --env GEOIPUPDATE_ACCOUNT_ID \
    --env GEOIPUPDATE_LICENSE_KEY \
    --env geoipupdate_db_dir \
    "${GEOIPUPDATE_DOCKER_IMAGE}"
else
    echo "INFO: dry run mode enabled (GEOIPUPDATE_DRYRUN is either false or undefined)"
    [[ "$(uname  || true)" == "Darwin" ]] && dateCmd="gdate" || dateCmd="date"
    currentUTCdatetime="$("${dateCmd}" --utc +"%Y%m%dT%H%MZ")"
    echo "dry-run" >"${geoipupdate_db_dir}/dryrun-${currentUTCdatetime}.mmdb"
    echo '[{"edition_id":"GeoLite2-ASN","old_hash":"c54b6e64478adfd010c7a86db310033f","new_hash":"857a0cf8118b9961cf6789e1842bce2a","modified_at":1733403617,"checked_at":1733756616},{"edition_id":"GeoLite2-City","old_hash":"34a6a0ec4018c74a503134980c154502","new_hash":"fb3449d8252f74eac39fc55c32c19879","modified_at":1733501742,"checked_at":1733756620},{"edition_id":"GeoLite2-Country","old_hash":"627a1d220b5ef844e0f0f174a0161cd7","new_hash":"27b1f57ae9dd56e1923f5d458514794c","modified_at":1733506208,"checked_at":1733756621}]' > "${geoipupdate_json_report}"
    ## Use this version to test, in dry run, the case of "not changed data"
    # echo '[{"edition_id":"GeoLite2-ASN","old_hash":"857a0cf8118b9961cf6789e1842bce2a","new_hash":"857a0cf8118b9961cf6789e1842bce2a","checked_at":1733760216},{"edition_id":"GeoLite2-City","old_hash":"fb3449d8252f74eac39fc55c32c19879","new_hash":"fb3449d8252f74eac39fc55c32c19879","checked_at":1733760216},{"edition_id":"GeoLite2-Country","old_hash":"27b1f57ae9dd56e1923f5d458514794c","new_hash":"27b1f57ae9dd56e1923f5d458514794c","checked_at":1733760216}]' > "${geoipupdate_json_report}"
fi

ls -ltra "${geoipupdate_db_dir}"/
cat "${geoipupdate_json_report}"

exit 0
