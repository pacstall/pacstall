<p align="center">
    <a href="https://github.com/pacstall/pacstall"><img align="center" height="150" src="https://raw.githubusercontent.com/pacstall/website/master/client/public/pacstall.svg" alt="Pacstall Logo" /></a>
</p>
<h1 align="center">Pacstall</h1>
<p align="center"><b>The AUR Ubuntu never had</b></p>

<p align="center">
    <!-- Programming info -->
    <a href="https://www.python.org/"><img alt="python 3.8+" src="https://img.shields.io/badge/python-3.8%2B-306998?logo=python&logoColor=white&style=for-the-badge" /></a>
    <a href="https://github.com/psf/black"><img alt="code style: 3.8+" src="https://img.shields.io/badge/code%20style-black-black?style=for-the-badge" /></a>
    <a href="https://www.codacy.com/gh/pacstall/pacstall/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=pacstall/pacstall&amp;utm_campaign=Badge_Grade">
        <img alt="Codacy branch grade" src="https://img.shields.io/codacy/grade/3c7e992f7e464b16919b7d57e524c997/python3-rewrite?logo=codacy&style=for-the-badge" />
    </a>
    <a href="https://www.gnu.org/software/bash"><img alt="bash v5" src="https://img.shields.io/badge/bash-v5-chateauGreen?logo=gnubash&logoColor=white&style=for-the-badge" /></a>
    <br />
    <!-- Social -->
    <a href="https://discord.gg/yzrjXJV6K8"><img alt="join discord" src="https://img.shields.io/discord/839818021207801878?color=5865F2&label=Discord&logo=discord&logoColor=FFFFFF&style=for-the-badge" /></a>
    <a href="https://reddit.com/r/pacstall"><img src="https://img.shields.io/reddit/subreddit-subscribers/pacstall?label=Reddit&color=FF4301&style=for-the-badge&logo=reddit&logoColor=FFFFFF" loading="lazy" /></a>
    <a href="https://social.linux.pizza/web/@pacstall">
        <img alt="Mastodon Follow" src="https://img.shields.io/mastodon/follow/107278715447740005?color=3088d4&domain=https%3A%2F%2Fsocial.linux.pizza&label=Mastodon&logo=mastodon&logoColor=white&style=for-the-badge" loading="lazy" />
    </a>
    <a href="https://matrix.to/#/#pacstall:matrix.org"><img alt="join matrix" src="https://img.shields.io/matrix/pacstall:matrix.org?color=888888&label=Matrix&logo=Matrix&style=for-the-badge" /></a>
    <br />
    <!-- Link to the programs repository -->
    <a href="https://github.com/pacstall/pacstall-programs">
        <img alt="https://github.com/pacstall/pacstall-programs" src="https://img.shields.io/github/commit-activity/m/pacstall/pacstall-programs?style=for-the-badge&label=programs%20repo%20activity" />
    </a>
</p>

## What is this

Pacstall is an AUR inspired package manager for Ubuntu. It takes the AUR and
puts a spin on it, making it easier to install programs without scouring github
repos and the likes.

You can find the list of avaiable packages to install
[here](https://github.com/pacstall/pacstall-programs/tree/master/packages).

## Features

* Supports [AppImage](https://appimage.org), binary, building, `.deb` and git
  packages.
* Asynchronous downloads.
* Auto update checks for git packages, so you always get the latest build of
  your favourite program off the latest commit by the developer.
* Track multiple pacscript sources, instead of just the official one.
* Completions available for `bash`,`fish`,`powershell`,`pwsh` and `zsh`.

## Installation

To install the latest release run:

```console
$ pip install pacstall
```

To install the latest development build run:

```console
$ pip install git+https://github.com/pacstall/pacstall@python3-rewrite
```

## Usage

```console
Usage: pacstall [OPTIONS] COMMAND [ARGS]...

  An AUR inspired package manager for Ubuntu.

Options:
  -v, --version         Show version and exit.
  -d, --debug           Turn on debugging info.
  --install-completion  Install completion for the current shell.
  --show-completion     Show completion for the current shell, to copy it or
                        customize the installation.
  -h, --help            Show this message and exit.

Commands:
  download  Download pacscripts.
  install   Install packages.
  list      List installed packages.
  remove    Remove packages.
  repo      List installed package sources.
  search    Search for packages.
  show      Show information about packages.
  upgrade   Upgrade packages.
```

For more information on each command, run `pacstall <command> -h`.

You can read the full usage
[here](https://github.com/pacstall/pacstall/wiki/Pacstall-2.0-Usage).

## Auto completions

To install the auto completions for your shell run:

```console
$ pacstall --install-completion
```

## Stats

<p align="center"><img alt="Repobeats analytics image" src="https://repobeats.axiom.co/api/embed/ba51853c4b477dcb6b2f3ad9c183f8d7086d027c.svg" /></p>

## License

<p align="center"><img alt="GPL-3.0-or-later" height="100" src="https://www.gnu.org/graphics/gplv3-or-later.svg" /></p>

```monospace
    ____                  __        ____
   / __ \____ ___________/ /_____ _/ / /
  / /_/ / __ `/ ___/ ___/ __/ __ `/ / /
 / ____/ /_/ / /__(__  ) /_/ /_/ / / /
/_/    \__,_/\___/____/\__/\__,_/_/_/

Copyright (C) 2021-present

This file is part of Pacstall

Pacstall is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Pacstall is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Pacstall.  If not, see <https://www.gnu.org/licenses/>.
```
