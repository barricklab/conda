#!/usr/bin/env bash
set -euo pipefail

REMOTE_SHA=$(git ls-remote https://github.com/barricklab/CNery.git HEAD | cut -f1)
LAST_SHA=$(jq -r '.cnery_commit_sha // ""' state/last-published-cnery-commit.json 2>/dev/null || echo "")

echo "remote_sha=${REMOTE_SHA}" >> "$GITHUB_OUTPUT"
echo "last_sha=${LAST_SHA}" >> "$GITHUB_OUTPUT"

if [[ "${REMOTE_SHA}" == "${LAST_SHA}" && "${FORCE_BUILD:-false}" != "true" ]]; then
  echo "has_new_commit=false" >> "$GITHUB_OUTPUT"
  echo "No new commit on barricklab/CNery (still at ${REMOTE_SHA})."
  exit 0
elif [[ "${REMOTE_SHA}" == "${LAST_SHA}" ]]; then
  echo "has_new_commit=true" >> "$GITHUB_OUTPUT"
  echo "Forcing build despite no new commit (still at ${REMOTE_SHA})."
else
  echo "has_new_commit=true" >> "$GITHUB_OUTPUT"
  echo "New commit on barricklab/CNery: ${LAST_SHA:-<none>} -> ${REMOTE_SHA}"
fi

# Only worth cloning when there is actually a build to version. CNery has no release tags yet, so
# 0.1.0 is the fallback base: above the 0.0.0 packages already published, below any future v1 tag.
bash scripts/derive_version.sh https://github.com/barricklab/CNery.git "${REMOTE_SHA}" 0.1.0 \
  | tee -a "$GITHUB_OUTPUT"
