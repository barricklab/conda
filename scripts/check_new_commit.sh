#!/usr/bin/env bash
set -euo pipefail

REMOTE_SHA=$(git ls-remote https://github.com/barricklab/breseq.git HEAD | cut -f1)
LAST_SHA=$(jq -r '.breseq_commit_sha // ""' state/last-published-commit.json 2>/dev/null || echo "")

echo "remote_sha=${REMOTE_SHA}" >> "$GITHUB_OUTPUT"
echo "last_sha=${LAST_SHA}" >> "$GITHUB_OUTPUT"

if [[ "${REMOTE_SHA}" == "${LAST_SHA}" ]]; then
  echo "has_new_commit=false" >> "$GITHUB_OUTPUT"
  echo "No new commit on barricklab/breseq (still at ${REMOTE_SHA})."
else
  echo "has_new_commit=true" >> "$GITHUB_OUTPUT"
  echo "New commit on barricklab/breseq: ${LAST_SHA:-<none>} -> ${REMOTE_SHA}"
fi
