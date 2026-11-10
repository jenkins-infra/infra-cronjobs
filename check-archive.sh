#!/bin/bash
set -eux -o pipefail

: "${ARCHIVE_NAME:?Set ARCHIVE_NAME}"

ARCHIVE_FOLDER="${ARCHIVE_FOLDER:-$(pwd)}"
archive_path="${ARCHIVE_FOLDER}/${ARCHIVE_NAME}"
test -d "${ARCHIVE_FOLDER}"
test -f "${archive_path}"

archive_list="$(tar --list --file "${archive_path}")"
if [[ -z "${archive_list}" ]]; then
	echo 'ERROR: invalid archive'
	exit 1
fi
archive_size="$(du -sh "${archive_path}" | cut -f1)"
archive_folder_count="$(grep --count '/$' <<< "${archive_list}")"
archive_file_count="$(grep --count --invert-match '/$' <<< "${archive_list}")"

# Files that can be used outside of this script
echo "${archive_size}, ${archive_file_count} files in ${archive_folder_count} folders" > "${archive_path}.description"
echo "${archive_list}" > "${archive_path}.list"
