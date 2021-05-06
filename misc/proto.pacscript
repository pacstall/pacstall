name="foo-git"
pkgname="foo"
version="1.0"
url="https://github.com/Henryws/pacstall/foo.git"
license="GPL"
build_depends="make gcc"
depends="neofetch plasma"
breaks="libfoo-git"

prepare() {
          command -v {make,gcc}
}

build() {
        ./configure
        make -j$(nproc)
}

install() {
          sudo make install DESTDIR=/usr/src/pacstall/foo-git
}
