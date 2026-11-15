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

# On Intel, many bundled dependencies (sdsl-lite, DYNAMIC, dozeu, ips4o, atomic_queue, gfakluge)
# hard-code -march=native, which would tie the package to the build runner's CPU (AVX2/AVX-512).
# Target SSE4.2 + POPCNT like vgteam's Linux binaries. (arm64 has a single baseline, so leave it.)
if [[ "$(uname -m)" == "x86_64" ]]; then
    # (grep exits 1 for a batch without matches; that is not an error here)
    native_files=$(find deps \( -name CMakeLists.txt -o -name Makefile -o -name '*.cmake' -o -name '*.mk' \) \
        -type f -exec grep -lE -- '-m(arch|tune)=native' {} + || true)
    for f in ${native_files}; do
        sed -i.bak -e 's/-march=native/-msse4.2 -mpopcnt/g' -e 's/-mtune=native//g' "${f}"
        rm -f "${f}.bak"
        echo "removed -march/-mtune=native from ${f}"
    done
fi

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

# Report wide-vector instructions. Some are expected (htslib and libdeflate pick AVX2/AVX-512
# code paths at run time); a large count would point at a dependency still built for the runner.
if [[ "$(uname -m)" == "x86_64" ]]; then
    otool -tv bin/vg > vg.disasm
    echo "instructions using ymm registers: $(grep -c '%ymm' vg.disasm || true)"
    echo "instructions using zmm registers: $(grep -c '%zmm' vg.disasm || true)"
    rm -f vg.disasm
fi

install -d "${PREFIX}/bin"
install -m 755 bin/vg "${PREFIX}/bin/vg"
