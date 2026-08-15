#!/usr/bin/env bash
#
# Derive the conda version and build string for a prerelease package from upstream git history.
#
# Usage: derive_version.sh <git-url> <commit-sha> <fallback-base>
# Prints, on stdout:
#   version=<PEP440 version>
#   build_string=g<short sha>
#
# Callers in CI append that output to "$GITHUB_OUTPUT"; the build jobs then pass it to conda-build
# through the environment. The recipes used to compute this themselves from conda-build's
# GIT_DESCRIBE_* variables, but Jinja cannot express "ignore a tag that is not a release tag" --
# see the tag filtering below for why that matters.
set -euo pipefail

URL="$1"
SHA="$2"
FALLBACK_BASE="$3"

WORK=$(mktemp -d)
trap 'rm -rf "${WORK}"' EXIT

# Full history (commit counts need it) without file contents.
git clone --quiet --filter=blob:none --no-checkout "${URL}" "${WORK}/src"

# Nearest *release* tag reachable from SHA. Requiring a dot in the tag excludes both kinds of
# upstream tag that are not releases: CNery's `testdata-<dataset>-v1` asset tags, which broke the
# build once CNery gained its first tags, and breseq's `v1-rc5`. Both contain hyphens, which conda
# rejects outright in a version.
TAG=$(git -C "${WORK}/src" describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*' "${SHA}" 2>/dev/null || echo "")

# Second gate, in case a future tag slips through the glob: a release tag is a plain dotted number.
if [[ -n "${TAG}" && ! "${TAG}" =~ ^v[0-9]+(\.[0-9]+)*$ ]]; then
  echo "Ignoring non-release tag: ${TAG}" >&2
  TAG=""
fi

if [[ -n "${TAG}" ]]; then
  BASE="${TAG#v}"
  COUNT=$(git -C "${WORK}/src" rev-list --count "${TAG}..${SHA}")
else
  # No release tag upstream. Anchor on a fixed base and count every commit rather than reusing
  # conda-build's GIT_DESCRIBE_NUMBER, which counts from the nearest tag of any kind: the next
  # `testdata-*` tag would reset it to 0 and the published version would go backwards.
  echo "No release tag reachable from ${SHA}; using fallback base ${FALLBACK_BASE}." >&2
  BASE="${FALLBACK_BASE}"
  COUNT=$(git -C "${WORK}/src" rev-list --count "${SHA}")
fi

SHORT=$(git -C "${WORK}/src" rev-parse --short=8 "${SHA}")

if [[ "${COUNT}" == "0" ]]; then
  VERSION="${BASE}"
else
  VERSION="${BASE}.dev${COUNT}+g${SHORT}"
fi

echo "version=${VERSION}"
echo "build_string=g${SHORT}"
