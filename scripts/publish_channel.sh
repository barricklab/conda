#!/usr/bin/env bash
set -euo pipefail

# Copies newly-built packages from downloaded-pkgs/pkg-<subdir>/ into the
# existing channel/ tree (checked out from gh-pages) without removing any
# previously published package files. Run from the repo root.

for pkg_dir in downloaded-pkgs/pkg-*; do
  [[ -d "${pkg_dir}" ]] || continue
  subdir=$(basename "${pkg_dir}" | sed 's/^pkg-//')
  mkdir -p "channel/${subdir}"
  cp -n "${pkg_dir}"/*.conda "channel/${subdir}/" 2>/dev/null || true
done
