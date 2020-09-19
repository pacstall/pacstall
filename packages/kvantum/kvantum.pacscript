name="kvantum"
pkgname="kvantum"
version="0.16.1"
url="https://github.com/tsujan/Kvantum/archive/V0.16.1.zip"
license="GPL"
build_depends="g++ libx11-dev qtbase5-dev libqt5svg5-dev libqt5x11extras5-dev libkf5windowsystem-dev cmake"
gives="kvantum"
breaks="qt5-style-kvantum"

prepare() {
          cd Kvantum-$version
          cd Kvantum
          mkdir build && cd build
}

build() {
        cmake ..
        make
}

install() {
          sudo porg -lp kvantum "make install"
}
