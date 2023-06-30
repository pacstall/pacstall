<p align="center">
<a href="https://github.com/pacstall/pacstall/releases/latest"><img src="https://img.shields.io/github/v/release/pacstall/pacstall?color=red&style=flat-square"></a>
<a href="https://www.gnu.org/software/bash/"><img src="https://img.shields.io/badge/bash-v5-brightgreen?style=flat-square&logo" alt="Bash v5"></a>
  <a href="https://github.com/pacstall/pacstall/issues"><img src="https://img.shields.io/github/issues/pacstall/pacstall?style=flat-square"></a>
<a href="https://github.com/pacstall/pacstall/actions?query=workflow%3A%22test+install+script%22"><img src="https://img.shields.io/github/actions/workflow/status/pacstall/pacstall/remote-bash.yml?branch=master&style=flat-square"></a>
<a href="https://www.codefactor.io/repository/github/pacstall/pacstall"><img src="https://img.shields.io/codefactor/grade/github/pacstall/pacstall/develop?style=flat-square"></a>
<a href="https://github.com/pacstall/pacstall-programs"><img src="https://img.shields.io/github/commit-activity/m/pacstall/pacstall-programs?style=flat-square&label=user%20repo%20activity"></a><br>
<a href="https://discord.gg/yzrjXJV6K8"><img src="https://img.shields.io/discord/839818021207801878?color=5865F2&label=Discord&logo=discord&logoColor=FFFFFF&style=flat-square"></a>
<a href="https://matrix.to/#/#pacstall:matrix.org"><img src="https://img.shields.io/matrix/pacstall:matrix.org?color=888888&label=Matrix&logo=Matrix&style=flat-square"></a>
<a href="https://lemmy.ml/c/pacstall/"><img src="https://img.shields.io/badge/Lemmy-red?logo=lemmy&logoColor=white&style=flat-square"></a>

</p>

<p align="center"><b>PACSTALL</b></p>
<p align="center">
<a href="https://github.com/pacstall/pacstall"><img align="center" src="https://raw.githubusercontent.com/pacstall/website/master/client/public/pacstall.svg" width="200" height="200" alt="Pacstall Logo"></a>
</p>
<p align="center"><b>The AUR Ubuntu never had</b></p>

<p align="center">Pacstall is the AUR Ubuntu wishes it had. It takes the concept of the AUR and puts a spin on it, making it easier to install programs without scouring github repos and the likes.</p>
<p align="center">The list of available packages can be found <a href="https://pacstall.dev/packages">here</a>.</p>
</p>

---

### Features

*  Supports binary, git, appimage, building and `.deb` packages
*  Accelerated package download using [axel](https://github.com/axel-download-accelerator/axel) (optional)
*  During upgrades, you always get the latest build off of the latest commit from the developer for `-git` packages. No need to wait for the pacscript maintainer to update the script!
*  Ability to install programs from multiple repositories
*  Ability to track Pacstall updates from any fork/branch easily
*  Completions available for `bash` (`ZSH`), and `fish`

---

### Installing

You can run the command below to install Pacstall.
You can also grab the deb file [here](https://github.com/pacstall/pacstall/releases/latest) but it may be a bit older.
```bash
sudo bash -c "$(curl -fsSL https://pacstall.dev/q/install || wget -q https://pacstall.dev/q/install -O -)"
```

### Uninstalling

You can run the command below to uninstall Pacstall.
```bash
bash -c "$(curl -fsSL https://pacstall.dev/q/uninstall || wget -q https://pacstall.dev/q/uninstall -O -)"
```
---

### Basic Commands
Install `foo` (Equivalent of `apt install`):
```bash
pacstall -I foo
```

Remove `foo` (Equivalent of `apt remove`):
```bash
pacstall -R foo
```

Search for `foo` (Equivalent of `apt search`):
```bash
pacstall -S foo
```

Adding a Repository:
```bash
pacstall -A REPOSITORY_NAME
```

Update Pacstall's Scripts:
```bash
pacstall -U
```

Update Packages (Equivalent of `apt upgrade`):
```bash
pacstall -Up
```

These are the basic commands, for more info, run `pacstall -h`

---
### Auto completions
Pacstall has fully supported auto completions for the `bash`, and `fish` shells. For the `ZSH` shell you can emulate the completions using the following commands.
#### Zsh auto completion
Zsh can emulate bash completion scripts by default so all you have to do is add these to your `.zshrc` or wherever you source things:
```bash
autoload bashcompinit
bashcompinit
source /usr/share/bash-completion/completions/pacstall
```

### License
---
![GPLv3](https://www.gnu.org/graphics/gplv3-with-text-136x68.png)
```monospace
Pacstall is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License

Pacstall is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Pacstall. If not, see <https://www.gnu.org/licenses/>.
```
