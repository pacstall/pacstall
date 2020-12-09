name="emacs"
pkgname="emacs"
version="27.1"
url="https://gnu.askapache.com/emacs/emacs-27.1.tar.xz"
license="GPL"
build_depends="build-dep emacs26"
gives="emacs"
prepare() {
          ./autogen.sh
          ./configure
}

build() {
        make -j$(nproc)
}

install() {
          sudo porg -lp emacs "sudo make install"
}
