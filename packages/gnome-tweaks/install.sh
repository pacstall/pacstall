#!/bin/bash
meson builddir
ninja -C builddir
ninja -C builddir install
