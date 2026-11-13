#!/bin/bash
set -eux -o pipefail

: "${ARCHIVE_NAME:?Set ARCHIVE_NAME}"

ARCHIVE_FOLDER="${ARCHIVE_FOLDER:-$(pwd)}"
test -d "${ARCHIVE_FOLDER}"
mvn_local_repo="${MVN_LOCAL_REPO:-"${HOME}/.m2/repository"}"
mvn_archive_path="${ARCHIVE_FOLDER}/${ARCHIVE_NAME}"

## Cache archive generation from local Maven repository
pushd "${mvn_local_repo}"

# Remove Maven internal resolutions files
find . -type f -name '_remote.repositories' -exec rm -f {} \; || true
# Remove cached resolution failures
find . -type f -name '*.lastUpdated' -exec rm -f {} \;
# Remove P2 query cache
rm -rfv ./dev/equo/p2-data/queries

compression_opts=()
if [[ "${ARCHIVE_NAME}" == *.tar.gz ]]; then
  compression_opts=(--gzip)
fi
if [[ "${ARCHIVE_NAME}" == *.tar.zst ]]; then
  compression_opts=(--use-compress-program='zstd --ultra -22 -T0')
fi
du -sh .
time tar --create --no-xattrs "${compression_opts[@]}" --file="${mvn_archive_path}" ./

echo "${ARCHIVE_NAME}" > "${ARCHIVE_FOLDER}/maven_cache_archive_name"
