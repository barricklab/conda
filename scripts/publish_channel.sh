#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# Copies newly-built packages from downloaded-pkgs/pkg-<subdir>/ into the
# existing channel/ tree (checked out from gh-pages) without removing any
# previously published package files. Run from the repo root.

pkg_dirs=(downloaded-pkgs/pkg-*/)
if (( ${#pkg_dirs[@]} == 0 )); then
  echo "No downloaded-pkgs/pkg-* directories found. The publish job only runs" >&2
  echo "when at least one build succeeded, so there should always be one." >&2
  exit 1
fi

for pkg_dir in "${pkg_dirs[@]}"; do
  subdir=$(basename "${pkg_dir}" | sed 's/^pkg-//')
  pkgs=("${pkg_dir}"*.conda)
  if (( ${#pkgs[@]} == 0 )); then
    echo "${pkg_dir} contains no .conda files." >&2
    exit 1
  fi

  mkdir -p "channel/${subdir}"
  for pkg in "${pkgs[@]}"; do
    dest="channel/${subdir}/$(basename "${pkg}")"
    # -n: never overwrite an already-published file. Clients cache by filename,
    # so republishing different bits under the same name would be invisible.
    if [[ -e "${dest}" ]]; then
      echo "skipped (already published): ${dest}"
    else
      cp -n "${pkg}" "${dest}"
      echo "copied: ${dest}"
    fi
  done
done
