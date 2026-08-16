#!/usr/bin/env bash
set -euo pipefail

# Copies newly-built packages from downloaded-pkgs/ into the existing channel/
# tree (checked out from gh-pages) without removing any previously published
# package files. Each package's target subdir is read from the directory it
# arrived in; see list_downloaded_packages.sh. Run from the repo root.

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
listing=$(bash "${script_dir}/list_downloaded_packages.sh")

if [[ -z "${listing}" ]]; then
  echo "No .conda files found under downloaded-pkgs/. The publish job only runs" >&2
  echo "when at least one build succeeded, so there should always be one." >&2
  exit 1
fi

while IFS=$'\t' read -r subdir pkg; do
  mkdir -p "channel/${subdir}"
  dest="channel/${subdir}/$(basename "${pkg}")"
  # Never overwrite an already-published file. Clients cache by filename, so
  # republishing different bits under the same name would be invisible to them.
  if [[ -e "${dest}" ]]; then
    echo "skipped (already published): ${dest}"
  else
    cp "${pkg}" "${dest}"
    echo "copied: ${dest}"
  fi
done <<< "${listing}"
