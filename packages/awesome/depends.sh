#!/bin/bash
equals=$(command -v apt)
if [ $equals == /usr/bin/apt ] ; then
    sudo apt install -y liblua libtexluajit2 x11proto-dev xcb-proto libxcb-cursor0 libxcb-util-dev libxcb-keysyms1 linxcb-icccm4 libxcb-xfixes0 autotools-dev libxkbcommon-dev libstartup-notification-dev libcairo2 gir1.2-coglpango-1.0 glib gir1.2-gdkpixbuf-2.0 libxdg-basedir
fi
equals=$(command -v dnf)
if [ $equals == /usr/bin/dnf ] ; then
    sudo dnf install -y lua-libs luajit-devel xorg-x11-proto-devel xcb-proto xcb-util xcb-util-keysyms xcb-util-wm libxcb libxcb-util-xrm libxkbcommon startup-notification cairo pango glib ghc-gi-gio libghc-gi-gio-dev ghc-gi-gdkpixbuf libxdg-basedir
fi
