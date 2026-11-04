#!/bin/bash
set -eux -o pipefail

: "${MVN_ARCHIVE_NAME:?Set MVN_ARCHIVE_NAME}"

mvn_cache_dir="${MVN_CACHE_DIR:-"/tmp"}"
test -d "${mvn_cache_dir}"
mvn_local_repo="${MVN_LOCAL_REPO:-"${HOME}/.m2/repository"}"
mvn_cache_archive="${mvn_cache_dir}/${MVN_ARCHIVE_NAME}"
mvn_global_opts=("-Dmaven.repo.local=${mvn_local_repo}")
# As 'dependency:go-offline' always use latest and until https://github.com/jenkins-infra/helpdesk/issues/5198 is fixed let's pin to 3.10.0
mvn_dependency_offline_target='org.apache.maven.plugins:maven-dependency-plugin:3.10.0:go-offline'
script_dir="$(cd "$(dirname "$0")" && pwd -P)"

## BOM and additional spotless dependencies
test -d ./bom || git clone "https://github.com/jenkinsci/bom"
pushd ./bom

# Retrieve release lines and Jenkins Core branches to retrieve dependencies from using BOM's sample-plugin POM as source of truth
RELEASE_LINES="$(echo weekly && grep -F '.x</bom>' sample-plugin/pom.xml | sed -E 's, *<bom>(.+)</bom>,\1,g' | sort -rn)"
JENKINS_BRANCHES="$(sed -E 's/^weekly$/master/; s/^([0-9]+\.[0-9]+)\.x$/stable-\1/' <<< "${RELEASE_LINES}")"

# Stay in the bom for its sub-project 'sample-plugin'
while IFS= read -r build_line; do
	mvn_buildline_opts=("${mvn_global_opts[@]}")
	if [[ $build_line != "weekly" ]]; then
		mvn_buildline_opts+=("-P" "${build_line}")
	fi
	time mvn -pl sample-plugin \
		-DincludeScore=runtime,compile,test \
		"${mvn_buildline_opts[@]}" \
		"${mvn_dependency_offline_target}"
done <<< "${RELEASE_LINES}"

# Additional spotless dependencies specific to BOM
time mvn "${mvn_global_opts[@]}" spotless:check

popd

## Jenkins Core and additional missing dependencies
test -d ./jenkins || git clone "https://github.com/jenkinsci/jenkins"
pushd ./jenkins

while IFS= read -r branch; do
	git checkout "${branch}"
	time mvn "${mvn_global_opts[@]}" "${mvn_dependency_offline_target}"
done <<< "${JENKINS_BRANCHES}"

# Missing deps
missing_deps_file="${script_dir}"/missing-deps.txt
test -f "${missing_deps_file}"

while IFS= read -r missing || [[ -n "${missing}" ]]; do
	# Skip blank lines and comments
	[[ -z "${missing//[[:space:]]/}" || "${missing}" =~ ^[[:space:]]*# ]] && continue

	missing_group_id="$(echo "$missing" | cut -d':' -f1)"
	missing_artifact_id="$(echo "$missing" | cut -d':' -f2)"
	missing_packaging="$(echo "$missing" | cut -d':' -f3)"
	missing_version="$(echo "$missing" | cut -d':' -f4)"

	time mvn "${mvn_global_opts[@]}" dependency:get \
		-DgroupId="${missing_group_id}" \
		-DartifactId="${missing_artifact_id}" \
		-Dversion="${missing_version}" \
		-Dpackaging="${missing_packaging}"
done <"${missing_deps_file}"

popd

## Cache archive generation from local Maven repository
pushd "${mvn_local_repo}"

# Remove Maven internal resolutions files
find . -type f -name '_remote.repositories' -exec rm -f {} \; || true
# Remove cached resolution failures
find . -type f -name '*.lastUpdated' -exec rm -f {} \;

du -sh .
time tar --create --no-xattrs --gzip --file="${mvn_cache_archive}" ./
du -sh "${mvn_cache_archive}"
