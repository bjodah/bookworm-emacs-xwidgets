#!/bin/bash
set -euo pipefail
# Currently (2025-12-27), emacs-master requires webkit

# See e.g.:
#  - https://emacs.stackexchange.com/a/83179/13547
#  - https://www.reddit.com/r/emacs/comments/1hno6q1/comment/m4ppypy/
#  - https://debbugs.gnu.org/cgi/bugreport.cgi?bug=66068#107
if [ $# -eq 1 ]; then
    PREFIX="$1"
elif [ $# -eq 0 ]; then
    PREFIX=$HOME/.local
fi

URL=https://webkitgtk.org/releases/webkitgtk-2.41.91.tar.xz
BUILD_ROOT=${BUILD_ROOT:-/bld}
SRC_DIR_WEBKIT=$BUILD_ROOT/webkitgtk-2.41.91
BLD_DIR_WEBKIT=$BUILD_ROOT/webkitgtk-2.41.91-build
if [ ! -d "$SRC_DIR_WEBKIT" ]; then
    ( set -x; curl -Ls "$URL" | tar xJ -C $BUILD_ROOT )
fi

#     -DGPERF_EXECUTABLE=$(which google-pprof)

cmake \
    -DCMAKE_GENERATOR=Ninja \
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DPORT=GTK \
    -DENABLE_GAMEPAD=OFF \
    -DENABLE_SPELLCHECK=OFF \
    -DUSE_GSTREAMER_TRANSCODER=OFF \
    -S "$SRC_DIR_WEBKIT" \
    -B "$BLD_DIR_WEBKIT" \
    --fresh
cmake --build "$BLD_DIR_WEBKIT" --parallel $(( $(nproc) / 4 ))
cmake --install "$BLD_DIR_WEBKIT"
