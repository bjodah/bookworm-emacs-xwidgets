#!/bin/bash
set -euxo pipefail

cd "$(dirname ${BASH_SOURCE[0]})"

podman build -t localhost/emx1 env-1

run_in_env1() {
    podman run \
           --rm \
           -v $(pwd)/env-2/opt:/opt \
           -v $(pwd)/bld-2:/bld \
           -v $(pwd)/bld-2/ccache:/root/.ccache \
           -it localhost/emx1 \
           "${@}"
}

if [ ! -d env-2/opt/webkitgtk/include ]; then
    run_in_env1 /bld/e0-webkitgtk-2.41.91.sh /opt/webkitgtk
    if [ ! -d ./env-2/opt/webkitgtk/include ]; then
        >&2 echo "Failed to build webkit2gtk?"
        exit 1
    fi
fi

if [ ! -d env-2/opt/tree-sitter ]; then
    run_in_env1 /bld/e0-tree-sitter.sh /opt/tree-sitter
    if [ ! -d ./env-2/opt/tree-sitter ]; then
        >&2 echo "Failed to build tree-sitter?"
        exit 1
    fi
fi

if [ ! -d env-2/opt/emacs ]; then
    run_in_env1 env \
                PKG_CONFIG_PATH=/opt/tree-sitter/lib/pkgconfig:/opt/webkitgtk/lib/pkgconfig \
                LDFLAGS="-Wl,-rpath,/opt/tree-sitter/lib -Wl,--disable-new-dtags -Wl,-rpath,/opt/webkitgtk/lib" \
                /bld/e1-emacs.sh \
                --make-command "make V=1" \
                --git-branch master \
                --cflags '-O2 -march=native' \
                --install /opt/emacs \
                --build-root /bld \
                -- --without-native-compilation --with-xwidgets --with-pgtk
fi

podman build -t localhost/emx2 env-2

podman run \
       --rm \
       -e DISPLAY \
       -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
       -it localhost/emx2 \
       env LD_LIBRARY_PATH=/opt/webkitgtk/lib /opt/emacs/bin/emacs
