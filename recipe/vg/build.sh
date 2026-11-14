#!/bin/bash
set -exo pipefail

# vg's Makefile looks for its dependencies under HOMEBREW_PREFIX (headers, libs, libomp);
# point it at the host prefix. NO_SYSTEM_PREFIXES keeps /usr/local and /opt/local out.
export HOMEBREW_PREFIX="${PREFIX}"
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
export CMAKE_PREFIX_PATH="${PREFIX}"
export CMAKE_IGNORE_PREFIX_PATH="/opt/homebrew;/usr/local;/opt/local"
# Keep Homebrew/MacPorts tools off PATH (GitHub's macOS runners have Homebrew's libtool).
# Bundled autogen.sh scripts (snappy) prefer `glibtoolize`, the Homebrew/MacPorts name, whose
# version then mismatches conda's libtool macros.
PATH="$(echo "${PATH}" | tr ':' '\n' | grep -vE '^(/opt/homebrew|/usr/local|/opt/local)(/|$)' | paste -sd: -)"
export PATH
export LIBTOOLIZE=libtoolize

# CMake 4 rejects cmake_minimum_required(< 3.5) in several bundled deps (DYNAMIC, raptor, libdivsufsort).
export CMAKE_POLICY_VERSION_MINIMUM=3.5

# vg is built with -O3 and with assert() enabled (upstream never sets NDEBUG, and many asserts
# have side effects, e.g. assert(getline(...)) in the GTF parser). conda's flags would override
# both: -O2 comes after vg's -O3, and CPPFLAGS carries -DNDEBUG.
CFLAGS="${CFLAGS//-O2/}"
CXXFLAGS="${CXXFLAGS//-O2/}"
CPPFLAGS="${CPPFLAGS//-DNDEBUG/}"
export CFLAGS CXXFLAGS CPPFLAGS

MAKE_ARGS=(NO_SYSTEM_PREFIXES=1 VG_PORTABLE=1)

make "${MAKE_ARGS[@]}" -j"${CPU_COUNT}"

# The bundled libraries are built both as .a and .dylib, and the dylibs are needed while
# building the other bundled libraries. For the final link of vg, offer only the archives so
# libvgio, libhandlegraph, htslib and libdeflate are linked statically (a bundled libhts.dylib
# would clash with conda's htslib).
mkdir -p lib_static
for a in lib/*.a; do ln -sf "../${a}" lib_static/; done
rm -f bin/vg
make "${MAKE_ARGS[@]}" LD_LIB_DIR_FLAGS="-L${PWD}/lib_static" bin/vg

# Fail if anything still points into the build tree.
if otool -L bin/vg | grep -q "${SRC_DIR}"; then
    otool -L bin/vg
    echo "bin/vg links against libraries in the build directory" >&2
    exit 1
fi

install -d "${PREFIX}/bin"
install -m 755 bin/vg "${PREFIX}/bin/vg"
