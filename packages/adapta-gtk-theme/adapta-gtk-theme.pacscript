name="adapta-gtk-theme"
pkgname="adapta-gtk-theme"
url="https://github.com/adapta-project/adapta-gtk-theme.git"
license="CC-BY-SA"
build_depends="autoconf automake inkscape libgdk-pixbuf2.0-dev libglib2.0-dev libxml2-utils pkg-config sassc"
gives="adapta-gtk-theme"
breaks="adapta"
description="An adaptive Gtk+ theme based on Material Design Guidelines"

prepare() {
          command -v $build_depends
          ./autogen.sh --prefix=/usr
}

build() {
        make -j$(nproc)
}

install() {
          sudo make install DESTDIR=/usr/src/pacstall/adapta-gtk-theme
}
