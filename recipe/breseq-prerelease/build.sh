#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname)" == "Linux" ]]; then
  export LIBS="${LIBS} -ldl"
fi

export INCLUDES="-I${PREFIX}/include"
export LIBPATH="-L${PREFIX}/lib"
export LDFLAGS="${LDFLAGS} -L${PREFIX}/lib"
export M4="${BUILD_PREFIX}/bin/m4"

./bootstrap.sh
./configure --prefix="${PREFIX}" \
	CXX="${CXX}" \
	CXXFLAGS="${CXXFLAGS} -O3 -I${PREFIX}/include" \
	LDFLAGS="${LDFLAGS}"
make -j"${CPU_COUNT}"
make install