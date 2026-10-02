#!/bin/bash

set -eux -o pipefail

test -d "${GEOIPUPDATE_DB_DIR?'ERRROR: environment variable GEOIPUPDATE_DB_DIR must be set.'}" || { echo "ERROR: no directory at the value provided by GEOIPUPDATE_DB_DIR (${GEOIPUPDATE_DB_DIR})"; exit 1; }
geoipupdate_docker_image="${GEOIPUPDATE_DOCKER_IMAGE?'ERRROR: environment variable GEOIPUPDATE_DOCKER_IMAGE must be set.'}"

geoipupdatejsonpath="$(mktemp)"
if [ "${GEOIPUPDATE_DRYRUN:-false}" == "true" ]; then
    docker run --rm --volume "${GEOIPUPDATE_DB_DIR}:${GEOIPUPDATE_DB_DIR}:rw" --entrypoint=geoipupdate "${geoipupdate_docker_image}" --output --database-directory="${GEOIPUPDATE_DB_DIR}" > "${geoipupdatejsonpath}"
else
    echo "INFO: dry run mode enabled (GEOIPUPDATE_DRYRUN is either false or undefined)"
    [[ "$(uname  || true)" == "Darwin" ]] && dateCmd="gdate" || dateCmd="date"
    currentUTCdatetime="$("${dateCmd}" --utc +"%Y%m%dT%H%MZ")"
    echo "dry-run" >"${GEOIPUPDATE_DB_DIR}/dryrun-${currentUTCdatetime}.mmdb"
    echo '[{"edition_id":"GeoLite2-ASN","old_hash":"c54b6e64478adfd010c7a86db310033f","new_hash":"857a0cf8118b9961cf6789e1842bce2a","modified_at":1733403617,"checked_at":1733756616},{"edition_id":"GeoLite2-City","old_hash":"34a6a0ec4018c74a503134980c154502","new_hash":"fb3449d8252f74eac39fc55c32c19879","modified_at":1733501742,"checked_at":1733756620},{"edition_id":"GeoLite2-Country","old_hash":"627a1d220b5ef844e0f0f174a0161cd7","new_hash":"27b1f57ae9dd56e1923f5d458514794c","modified_at":1733506208,"checked_at":1733756621}]' > "${geoipupdatejsonpath}"
    ## Use this version to test, in dry run, the case of "not changed data"
    # echo '[{"edition_id":"GeoLite2-ASN","old_hash":"857a0cf8118b9961cf6789e1842bce2a","new_hash":"857a0cf8118b9961cf6789e1842bce2a","checked_at":1733760216},{"edition_id":"GeoLite2-City","old_hash":"fb3449d8252f74eac39fc55c32c19879","new_hash":"fb3449d8252f74eac39fc55c32c19879","checked_at":1733760216},{"edition_id":"GeoLite2-Country","old_hash":"27b1f57ae9dd56e1923f5d458514794c","new_hash":"27b1f57ae9dd56e1923f5d458514794c","checked_at":1733760216}]' > "${geoipupdatejsonpath}"
fi
jq -r . "${geoipupdatejsonpath}"

exit 0
