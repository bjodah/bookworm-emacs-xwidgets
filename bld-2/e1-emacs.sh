#!/bin/bash
set -euo pipefail

show_help(){
    echo "--git-branch <name>    e.g.: 'emacs-28', 'master'"
    echo "--with-pgtk            Enable pure-gtk backend (req. gtk3)"
    echo "--build-root           a shallow clone of emacs' repo will be put under this dir"
    echo "--cflags               Specify CFLAGS, defaults to optimized build"
    echo "--make-command         default: make, e.g.: 'bear -- make'"
    echo "--build-vterm          compiles vterm-module.so"
    echo ""
    echo "One of:"
    echo "--create-deb <outdir>  Build a debian dpkg/apt package, or:..."
    echo "--install <prefix>     Install into <prefix>"
    echo ""
    echo "Example:"
    echo "  \$ CC=gcc-10 ./$(basename $0) --git-branch emacs-29 -- --without-x --with-native-compilation=aot && which emacs"   
    echo "  /usr/local/bin/emacs"
    echo ""
    echo "  # git clone https://github.com/tree-sitter/tree-sitter && cd tree-sitter && make PREFIX=\$HOME/.local install"
    echo "  \$ PKG_CONFIG_PATH=\$HOME/.local/lib/pkgconfig LDFLAGS=\"-Wl,-rpath,\$HOME/.local/lib\" ./$(basename $0) --cflags '-O2 -march=native' --install \$HOME/.local --build-root /build -- --without-native-compilation"
}
EMACS_BRANCH="emacs-30"
WITH_PGTK=0
CREATE_DEB=0
BUILD_VTERM=0
INSTALL_PREFIX="/usr/local"
BUILD_ROOT=""
CFLAGS_GIVEN=""
MAKE_COMMAND="make"
while [ $# -gt 0 ]; do
    case "$1" in
	-h|--help|\?)
	    show_help
	    exit 0
	    ;;
	--git-branch)
	    shift
	    EMACS_BRANCH=$1
	    shift
	    ;;
	--cflags)
	    shift
	    CFLAGS_GIVEN="$1"
	    shift
	    ;;
	--build-root)
	    shift
	    BUILD_ROOT=$1
	    shift
	    ;;
	--make-command)
	    shift
	    MAKE_COMMAND=$1
	    shift
	    ;;
	--with-pgtk)
	    WITH_PGTK=1
	    shift
	    ;;
	--create-deb)
	    CREATE_DEB=1
	    shift
	    CREATE_DEB_OUTDIR="$1"
	    shift
	    ;;
	--build-vterm)
	    BUILD_VTERM=1
	    shift
	    ;;
	--install)
	    shift
	    INSTALL_PREFIX=$1
	    shift
	    ;;
	--)
	    shift
	    break
	    ;;
	*)
	    show_help
	    exit 1
	    ;;
    esac
done
if [[ $CREATE_DEB == 1 ]]; then
    if [[ $CREATE_DEB_OUTDIR == "" ]]; then
	>&2 echo "Got no --create-deb <dir>"
    fi
    if [[ ! -d "$CREATE_DEB_OUTDIR" ]]; then
	>&2 echo "No such output directory (--create-deb <dir>): $CREATE_DEB_OUTDIR"
	exit 1
    fi
fi
if [[ $BUILD_ROOT == "" ]]; then
    >&2 echo "Need to specify build root dir --build-root"
    exit 1
fi
mkdir -p ${BUILD_ROOT}
if [[ $BUILD_VTERM == 1 ]]; then
    if [ ! -e $BUILD_ROOT/e2-emacs-vterm.sh ]; then
        cp -a $(dirname $0)/e2-emacs-vterm.sh $BUILD_ROOT/
    fi
fi
if [[ $EMACS_BRANCH == "master" ]]; then
    EMACS_SRC_DIR=${BUILD_ROOT}/"emacs-master"
else
    EMACS_SRC_DIR=${BUILD_ROOT}/$EMACS_BRANCH
fi
if [[ ! -e $EMACS_SRC_DIR ]]; then
    ( set -x; git clone --depth 1 --branch $EMACS_BRANCH https://github.com/emacs-mirror/emacs $EMACS_SRC_DIR )
fi


cd $EMACS_SRC_DIR
sed -i '/pgtk_display_x_warning (dpy);$/d' src/pgtkterm.c  # I already know PGTK+X11 is unsupported...

./autogen.sh

if [[ $CFLAGS_GIVEN == "" ]]; then
    if [[ $(uname -m) == "x86_64" ]]; then
	export ARCH_FLAGS="-mtune=skylake -march=nehalem"
    else
	export ARCH_FLAGS=""
    fi
    CFLAGS_GIVEN="-Os -pipe $ARCH_FLAGS -fomit-frame-pointer"
fi

CONFIGURE_FLAGS="\
 --with-cairo\
 --with-dbus\
 --with-gif\
 --with-gpm=no\
 --with-harfbuzz\
 --with-jpeg\
 --with-xml2\
 --with-modules\
 --with-png\
 --with-rsvg\
 --with-tiff\
 --with-tree-sitter\
 --with-xft\
 --with-xpm\
 $@"

# --with-imagemagick
# --with-xwidgets
# PKG_CONFIG_PATH=$HOME/.local/lib/pkgconfig:/opt/webkitgtk-2.41.91/lib/pkgconfig LDFLAGS="-Wl,-rpath,$HOME/.local/lib -Wl,-rpath,/opt/webkitgtk-2.41.91/lib" ~/vc/bjodah-containers/build-scripts/e1-emacs.sh --git-branch master --cflags '-O2 -march=native' --install $HOME/.local --build-root /build -- --without-native-compilation --with-xwidgets


EMACS_FEATURES=""

if [[ $WITH_PGTK == 1 ]]; then
    CONFIGURE_FLAGS="$CONFIGURE_FLAGS --with-pgtk"
    EMACS_FEATURES="${EMACS_FEATURES}-pgtk"
else
    CONFIGURE_FLAGS="$CONFIGURE_FLAGS"
fi

if [[ $INSTALL_PREFIX != "" ]]; then
    CONFIGURE_FLAGS="$CONFIGURE_FLAGS --prefix=$INSTALL_PREFIX"
fi
if which ccache 2>&1 >/dev/null; then
    if [[ ${CC:-gcc} != ccache* ]]; then
        export CC="ccache ${CC:-gcc}"
    fi
    if [[ ${CXX:-g++} != ccache* ]]; then
        export CXX="ccache ${CXX:-g++}"
    fi
fi
( set -x; CFLAGS="$CFLAGS_GIVEN" ./configure $CONFIGURE_FLAGS ; grep -A1 'WARNING:' config.log)

( set -x; $MAKE_COMMAND -j $(nproc) )


if [[ $CREATE_DEB == 1 ]]; then
    EMACS_VERSION=$(grep -oP "AC_INIT\([\[]?GNU Emacs[\]]?,[ \[]+\K([0-9\.]+)(?=[ \]]*, .*)" configure.ac)
    EMACS_DEB_ROOT=$BUILD_ROOT/emacs${EMACS_FEATURES}_${EMACS_VERSION}
    mkdir -p $EMACS_DEB_ROOT$INSTALL_PREFIX
    make install prefix=$EMACS_DEB_ROOT$INSTALL_PREFIX
    if [[ $BUILD_VTERM == 1 ]]; then
        ( cd - ; env BUILD_ROOT=$BUILD_ROOT $BUILD_ROOT/e2-emacs-vterm.sh $EMACS_DEB_ROOT$INSTALL_PREFIX )
    fi
    mkdir $EMACS_DEB_ROOT/DEBIAN
    # libxml2-dev
    EMACS_DEB_DEP="libgif7, libotf1, libm17n-0, librsvg2-2, libtiff5, libjansson4, libacl1, libgmp10, libwebp7, libsqlite3-0, libxml2"
    EMACS_DEB_DESCR="Emacs $EMACS_VERSION ($EMACS_BRANCH)"
    if [[ $WITH_NATIVE_COMP == 1 ]]; then
	EMACS_DEB_DEP="$EMACS_DEB_DEP, libgccjit0"
	EMACS_DEB_DESCR="$EMACS_DEB_DESCR, with native compilation"
    fi
    if [[ $WITH_PGTK == 1 ]]; then
	EMACS_DEB_DEP="$EMACS_DEB_DEP, libgtk-3-0"
	EMACS_DEB_DESCR="$EMACS_DEB_DESCR, with pure-GTK"
    # else
    # 	EMACS_DEB_DEP="$EMACS_DEB_DEP, libwebkit2gtk-4.1-0"
    fi
    cat <<EOF >> $EMACS_DEB_ROOT/DEBIAN/control
Package: emacs${EMACS_FEATURES}
Version: ${EMACS_VERSION}
Section: base
Priority: optional
Architecture: $(dpkg-architecture --query DEB_TARGET_ARCH)
Depends: $EMACS_DEB_DEP
Maintainer: bjodah
Description: $EMACS_DEB_DESCR
    $CONFIGURE_FLAGS 
EOF
    dpkg-deb --build $EMACS_DEB_ROOT
    mv ${BUILD_ROOT}/emacs${EMACS_FEATURES}_${EMACS_VERSION}.deb "${CREATE_DEB_OUTDIR}"
elif [[ $INSTALL_PREFIX != "" ]]; then
    if [[ -w $INSTALL_PREFIX ]]; then
	make install
    else
	sudo make install
    fi
    if [[ $BUILD_VTERM == 1 ]]; then
        ( cd -; env BUILD_ROOT=$BUILD_ROOT $BUILD_ROOT/e2-emacs-vterm.sh $INSTALL_PREFIX )
    fi
    make clean
else
    >&2 echo "Unknown state, exiting."
    exit 1
fi
