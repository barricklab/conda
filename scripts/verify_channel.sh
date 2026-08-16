#!/usr/bin/env bash
set -euo pipefail

# Asserts that every package this run built is actually present in channel/
# before the gh-pages commit and the state write-back happen. Without this, a
# publish that copied nothing still commits (conda index rewrites index.html
# either way) and then advances state/, stranding the build.
#
# Expectations are derived from the downloaded artifacts rather than from a
# hardcoded platform list, so this covers whatever the build matrix produced.
# Run from the repo root.

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
listing=$(bash "${script_dir}/list_downloaded_packages.sh")

if [[ -z "${listing}" ]]; then
  echo "No .conda files found under downloaded-pkgs/, so nothing could have" >&2
  echo "been published." >&2
  exit 1
fi

missing=()
breseq_found=0
cnery_found=0

while IFS=$'\t' read -r subdir pkg; do
  name=$(basename "${pkg}")
  dest="channel/${subdir}/${name}"

  if [[ -f "${dest}" ]]; then
    echo "ok: ${dest}"
  else
    echo "MISSING: ${dest}"
    missing+=("${dest}")
  fi

  # Cross-check that what was built carries the version the check job derived,
  # so an env-var regression cannot publish a silently mislabelled package.
  if [[ "${BRESEQ_BUILT:-false}" == "true" && "${name}" == breseq-prerelease-* ]]; then
    if [[ "${name}" == "breseq-prerelease-${BRESEQ_VERSION}-${BRESEQ_BUILD_STRING}.conda" ]]; then
      breseq_found=$((breseq_found + 1))
    else
      echo "UNEXPECTED VERSION: ${name} (wanted breseq-prerelease-${BRESEQ_VERSION}-${BRESEQ_BUILD_STRING}.conda)" >&2
      exit 1
    fi
  fi

  if [[ "${CNERY_BUILT:-false}" == "true" && "${name}" == cnery-prerelease-* ]]; then
    if [[ "${name}" == "cnery-prerelease-${CNERY_VERSION}-${CNERY_BUILD_STRING}.conda" ]]; then
      cnery_found=$((cnery_found + 1))
    else
      echo "UNEXPECTED VERSION: ${name} (wanted cnery-prerelease-${CNERY_VERSION}-${CNERY_BUILD_STRING}.conda)" >&2
      exit 1
    fi
  fi
done <<< "${listing}"

if (( ${#missing[@]} > 0 )); then
  echo >&2
  echo "${#missing[@]} expected package(s) never made it into the channel:" >&2
  printf '  %s\n' "${missing[@]}" >&2
  exit 1
fi

if [[ "${BRESEQ_BUILT:-false}" == "true" && "${breseq_found}" -eq 0 ]]; then
  echo "The breseq build ran but no breseq-prerelease package was published." >&2
  exit 1
fi

if [[ "${CNERY_BUILT:-false}" == "true" && "${cnery_found}" -eq 0 ]]; then
  echo "The CNery build ran but no cnery-prerelease package was published." >&2
  exit 1
fi

echo "All expected packages are present in the channel."
