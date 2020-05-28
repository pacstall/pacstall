#!/bin/bash
~/.local/bin/meson builddir
ninja -C builddir
ninja -C builddir install
