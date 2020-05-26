GNOME TWEAKS
================


BUILD
-----
The only build-time dependency is [meson](https://mesonbuild.com/).

    meson builddir
    ninja -C builddir
    ninja -C builddir install

RUNTIME DEPENDENCIES
--------------------
* Python3
* pygobject (>= 3.10)
* gnome-settings-daemon
* sound-theme-freedesktop

* GIR files and libraries from:
  - GLib (>= 2.58)
  - GTK+ 3 (>= 3.12)
  - gnome-desktop (>= 3.30)
  - libhandy
  - libsoup
  - libnotify
  - Pango

* GSettings Schemas from:
  - gsettings-desktop-schemas (>= 3.33.0)
  - gnome-shell (>= 3.24)
  - mutter

* Optional:
   - gnome-software (for links from GNOME Shell Extensions page)
   - nautilus 3.26 or older (for icons on the desktop)

RUNNING
-------
 * If you wish to run the application uninstalled, execute;

    ./gnome-tweaks [-p /path/to/jhbuild/prefix/]

SUPPORTED DESKTOPS
------------------
Tweaks is designed for GNOME Shell but can be used in other desktops.
A few features will be missing when Tweaks is run on a different desktop.

TODO
----
 * I'm not sure if the TweakGroup layer is necessary, and it makes
   it hard to categorise things. Perhaps go to a named factory approach
 * Do some more things lazily to improve startup speed

HOMEPAGE
--------
https://wiki.gnome.org/Apps/Tweaks

DEVELOPMENT REPOSITORY
----------------------
https://gitlab.gnome.org/GNOME/gnome-tweaks

BUGS
----
https://gitlab.gnome.org/GNOME/gnome-tweaks/issues

LICENSE
-------
This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later version.

data/org.gnome.tweaks.appdata.xml.in is licensed under the [Creative Commons
CC0-1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode) license.
