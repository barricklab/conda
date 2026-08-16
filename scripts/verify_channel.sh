#!/usr/bin/env bash
set -euo pipefail

# Asserts that every package this run was supposed to publish is actually present
# in channel/ before the gh-pages commit and the state write-back happen. Without
# this, a publish that copied nothing still commits (conda index rewrites
# index.html either way) and then advances state/, stranding the build.
# Run from the repo root.

BRESEQ_SUBDIRS=(linux-64 linux-aarch64 osx-arm64 osx-64)

missing=()

check() {
  local path="$1"
  if [[ -f "${path}" ]]; then
    echo "ok: ${path}"
  else
    echo "MISSING: ${path}"
    missing+=("${path}")
  fi
}

if [[ "${BRESEQ_BUILT:-false}" == "true" ]]; then
  for subdir in "${BRESEQ_SUBDIRS[@]}"; do
    check "channel/${subdir}/breseq-prerelease-${BRESEQ_VERSION}-${BRESEQ_BUILD_STRING}.conda"
  done
fi

if [[ "${CNERY_BUILT:-false}" == "true" ]]; then
  check "channel/noarch/cnery-prerelease-${CNERY_VERSION}-${CNERY_BUILD_STRING}.conda"
fi

if (( ${#missing[@]} > 0 )); then
  echo >&2
  echo "${#missing[@]} expected package(s) never made it into the channel:" >&2
  printf '  %s\n' "${missing[@]}" >&2
  exit 1
fi

echo "All expected packages are present in the channel."
