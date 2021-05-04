This is a pacscript:

```bash
name="foo"
pkgname="foo"
version="1.0"
url="https://github.com/Henryws/foo/archive/refs/tags/1.0.zip"
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
        make -j$(nproc)
}

install() {
          sudo make install DESTDIR=/usr/src/pacstall
}
```


The `$name`:

The \$name variable is the name of your package

The `$pkgname`

The executable that will be run when the user want's to run \$name

The `$version`

self explanitory, use semantic versioning when possible

And the most important thing is to prepare, build, and install with all cores if possible for the fastest install time. For instance, `make` has an option to build with all cores. To use that, replace `make` with `make -j$(nproc)`. That will take the output of `nproc` which tells you how many cores your system has and build with that many cores.

One note on the install function is that the DESTDIR should always be /usr/src/pacstall unless it will refuse to function without. It keeps your system clean and helps with the scourge of not knowing where make put what on your system. Don't worry about PATH either, pacstall will take care of that. And the last thing to help with porg (tracks where make put what) is that porg should be run as root and not make install. Thats because porg tracks LD_PRELOAD, and sudo can mess with that and porg will report that no files have been made. And as a side bonus, it makes it easier to remove programs if pacstall goes haywire
