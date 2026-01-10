#!/bin/bash
set -euxo pipefail

EMACS_PREFIX=${1}
EMACS_SITE_LISP="$EMACS_PREFIX"/share/emacs/site-lisp
if [[ ! -d "$EMACS_SITE_LISP" ]]; then
    >&2 echo "Not a directory: $EMACS_SITE_LISP"
    exit 1
fi
BUILD_ROOT="${BUILD_ROOT:-/bld}"
mkdir -p "$BUILD_ROOT"
cd "$BUILD_ROOT"
if [[ -e emacs-sqlite3-api ]]; then
    env -C emacs-sqlite3-api git pull
    env -C emacs-sqlite3-api git clean -xfd
else
    git clone --depth 1 https://github.com/pekingduck/emacs-sqlite3-api
fi

BUILD_DIR="$BUILD_ROOT/build-emacs-sqlite3-api"
if [ -d "$BUILD_DIR" ]; then
    rm -r "$BUILD_DIR"
fi
cp -ra emacs-sqlite3-api "$BUILD_DIR"
cd "$BUILD_DIR"
PATH="$EMACS_PREFIX/bin:$PATH" make
cp sqlite3.el sqlite3-api.so $EMACS_SITE_LISP/   # see "Manual Installation" in the README
