#!/usr/bin/env bash
set -euo pipefail

# Prints one "<subdir><TAB><path>" line per downloaded package. The subdir comes
# from the directory the package sits in, which the build jobs embed in the
# artifact itself (see the `built-pkgs/*/*.conda` upload paths). Nothing here
# enumerates platforms, so adding or removing a build matrix entry needs no
# corresponding change in the publish job.
#
# Run from the repo root. Shared by publish_channel.sh and verify_channel.sh so
# the two agree on what was built without either trusting the other.

while IFS= read -r -d '' pkg; do
  subdir=$(basename "$(dirname "${pkg}")")

  # A package directly under downloaded-pkgs/, or under the artifact directory
  # itself, means the subdir never made it into the artifact — most likely the
  # upload `path:` lost its wildcard directory component. Refuse to guess.
  if [[ "${subdir}" == "downloaded-pkgs" || "${subdir}" == pkg-* ]]; then
    echo "${pkg} is not inside a <subdir>/ directory, so its target subdir is" >&2
    echo "unknown. Check that the upload-artifact paths still use the form" >&2
    echo "built-pkgs/*/*.conda, which preserves the subdir inside the artifact." >&2
    exit 1
  fi

  printf '%s\t%s\n' "${subdir}" "${pkg}"
done < <(find downloaded-pkgs -type f -name '*.conda' -print0)
