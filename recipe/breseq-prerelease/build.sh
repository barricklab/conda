#!/usr/bin/env bash
set -euo pipefail

./bootstrap.sh

if [[ "$(uname)" == "Linux" ]]; then
    ./configure \
        --prefix=$PREFIX \
        --with-pic \
        LIBS="-ldl"
else
    ./configure \
        --prefix=$PREFIX \
        --with-pic
fi
	
make -j"${CPU_COUNT}"
make install