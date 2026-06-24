#!/usr/bin/env bash
set -euo pipefail

./bootstrap.sh
./configure --prefix="${PREFIX}"
make -j"${CPU_COUNT}"
make install
