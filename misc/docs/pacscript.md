This is a pacscript:
```bash
name="foo"
pkgname="foo"
version="1.0"
url="https://github.com/Henryws/pacstall/foo.git"
license="GPL"
build_depends="vim gcc"
depends="neofetch plasma"
gives="libfoo"
breaks="libfoo-git"
rootprepare="false"
rootbuild="false"
rootinstall="true"

prepare() {
          command -v $depends
}

build() {
        ./configure
        make
}

install() {
          make install
}```

It looks like plain text but it is actually a bash script with variables and functions.

The $name:
  The $name variable is the name of your package
  
The $pkgname
  The executable that will be run when the user want's to run $name
  
The $version
  self explanitory
