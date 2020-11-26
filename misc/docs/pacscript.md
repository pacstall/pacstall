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

prepare() {
          command -v $depends
}

build() {
        ./configure
        make
}

install() {
          make install
}
```

It looks like plain text but it is actually a bash script with variables and functions.

The `$name`:

The \$name variable is the name of your package

The `$pkgname`

The executable that will be run when the user want's to run \$name

The `$version`

self explanitory

And the most important thing is to prepare build and install with all cores if possible. For instance, `make` has an option to build with all cores. To use that, replace `make` with `make -j$(nproc)`. That will take the output of `nproc` which tells you how many cores your system has and build with that many cores.
