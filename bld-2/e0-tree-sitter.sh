#!/bin/bash
set -euxo pipefail
BUILD_ROOT=${BUILD_ROOT:-/bld}
if [ -d "$BUILD_ROOT" ]; then
    cd "$BUILD_ROOT"
else
    cd /tmp
fi
if [ ! -d tree-sitter-0.26.3 ]; then
    #git clone --depth 1 https://github.com/tree-sitter/tree-sitter
    curl -Ls https://github.com/tree-sitter/tree-sitter/archive/refs/tags/v0.26.3.tar.gz | tar xz
fi
ls -l
make -C ./tree-sitter-0.26.3/ PREFIX="$1" install
