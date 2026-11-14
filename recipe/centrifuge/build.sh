#!/bin/bash

set -xe

export LDFLAGS="-L$PREFIX/lib"
export CPATH=${PREFIX}/include

mkdir -p $PREFIX/bin

# macOS filesystems are case-insensitive: with -I. the file VERSION shadows libc++'s <version>
# header. The patched Makefile reads VERSION.txt.
mv VERSION VERSION.txt

# RELEASE_FLAGS replaces Centrifuge's own flags, which include -std=c++11. The code uses
# std::auto_ptr, which libc++ (unlike libstdc++) removes in the compiler's default C++17 mode.
CXXFLAGS="${CXXFLAGS} -std=c++11"

case $(uname -m) in
    aarch64|arm64)
        CXXFLAGS="${CXXFLAGS} -fsigned-char"
        ARCH_OPTS="SSE_FLAG= POPCNT_CAPABILITY=0"
        ;;
    *)
        ARCH_OPTS=""
        ;;
esac

make -j ${CPU_COUNT} CXX=$CXX RELEASE_FLAGS="$CXXFLAGS" ${ARCH_OPTS}
make install prefix=$PREFIX

cp evaluation/{centrifuge_evaluate.py,centrifuge_simulate_reads.py} $PREFIX/bin
