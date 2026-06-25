# conda

A custom conda channel publishing automated pre-release builds of
[breseq](https://github.com/barricklab/breseq), tracking its `master` branch.

Channel URL (once published): `https://barricklab.github.io/conda/`

```
conda install -c https://barricklab.github.io/conda/ breseq-prerelease
```

This is **not** the stable `breseq` package (that's distributed via
[bioconda](https://bioconda.github.io/recipes/breseq/README.html)). Packages
here are built straight from breseq's `master` branch and may be broken or
unstable; use them to test in-development changes, not for production
analysis.

## How it works

- `recipe/breseq-prerelease/` is a conda-build recipe that builds breseq from
  a git checkout (`source.git_url`) rather than a release tarball, and derives
  a PEP440 dev version from `git describe` (e.g. `0.40.1.dev42+g3a91c4`).
- `.github/workflows/build-and-publish.yml` runs daily at 10:13 UTC (~6:13am
  US Eastern) and can also be triggered manually (`workflow_dispatch`): it
  checks whether breseq has a new commit since the last publish
  (`scripts/check_new_commit.sh`), and if so builds packages for Linux and
  macOS (Apple Silicon) and publishes them into the channel
  (`scripts/publish_channel.sh` + `conda index`) hosted on the `gh-pages`
  branch.
- `state/last-published-commit.json` (on `main`) records the last breseq
  commit that was successfully published, so re-running the workflow with no
  new upstream commits is a cheap no-op.

## Triggering a build

Runs automatically once a day. To trigger manually: from the GitHub UI,
Actions → "Build and publish breseq-prerelease" → Run workflow. Or via the
CLI:

```
gh workflow run build-and-publish.yml
gh run watch
```

Previously published package versions are never deleted — each run adds new
package files alongside existing ones and re-indexes the channel.

## Testing an install

`test-environment.yml` defines a throwaway environment pulling
`breseq-prerelease` from this channel:

```
conda env create -f test-environment.yml
conda activate breseq-prerelease-test
breseq --help
```
