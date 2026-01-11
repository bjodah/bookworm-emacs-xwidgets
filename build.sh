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
                --cflags '-O2 -march=sandybridge' \
                --install /opt/emacs \
                --build-root /bld \
                -- --without-native-compilation --with-xwidgets --with-pgtk
fi

if [ ! -e env-2/opt/emacs/share/emacs/site-lisp/vterm-module.so ]; then
    run_in_env1 env \
                BUILD_ROOT=/bld \
                /bld/e2-emacs-vterm.sh /opt/emacs
fi

if [ ! -e env-2/opt/emacs/share/emacs/site-lisp/sqlite3-api.so ]; then
    run_in_env1 env \
                BUILD_ROOT=/bld \
                /bld/e4-emacs-sqlite3-api.sh /opt/emacs
fi

if [ ! -e env-2/opt/emacs-d-milanglacier/straight ]; then
    run_in_env1 bash -c 'git clone --depth 1 https://github.com/milanglacier/dotemacs /opt/emacs-d-milanglacier \
  && /opt/emacs/bin/emacs --init-directory=/opt/emacs-d-milanglacier --batch --eval "(load-file \"/opt/emacs-d-milanglacier/init.el\")"'                
fi

if [ ! -e env-2/opt/emacs-d-minimal ]; then
    run_in_env1 bash -c 'git clone --depth 1 https://github.com/jamescherti/minimal-emacs.d /opt/emacs-d-jamescherti-minimal \
  && /opt/emacs/bin/emacs --init-directory=/opt/emacs-d-jamescherti-minimal --batch --eval "(progn (load-file \"/opt/emacs-d-jamescherti-minimal/early-init.el\") (load-file \"/opt/emacs-d-jamescherti-minimal/init.el\"))"'
fi

if [ ! -e env-2/opt/emacs-d-bedrock ]; then
    run_in_env1 bash -c 'git clone --depth 1 https://codeberg.org/ashton314/emacs-bedrock /opt/emacs-d-bedrock && \
  /opt/emacs/bin/emacs --init-directory=/opt/emacs-d-bedrock --batch --eval "(progn (load-file \"/opt/emacs-d-bedrock/early-init.el\") (load-file \"/opt/emacs-d-bedrock/init.el\"))"'
fi

podman build -t localhost/emx2 env-2

#CHOICE_OF_INIT_DIR_FOR_EMACS=bedrock
#CHOICE_OF_INIT_DIR_FOR_EMACS=jamescherti-minimal
CHOICE_OF_INIT_DIR_FOR_EMACS=milanglacier

podman run \
       --rm \
       -e DISPLAY \
       -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
       -it localhost/emx2 \
       env \
         LD_LIBRARY_PATH=/opt/webkitgtk/lib \
         /opt/emacs/bin/emacs \
           --init-directory /opt/emacs-d-${CHOICE_OF_INIT_DIR_FOR_EMACS}


