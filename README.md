<p align="center">
<a href="https://choosealicense.com/licenses/gpl-3.0/"><img src="https://img.shields.io/badge/license-GPL-blue.svg?style=flat-square&logo"></a>
<a href="https://github.com/pacstall/pacstall/releases/latest"><img src="https://img.shields.io/github/v/release/pacstall/pacstall?color=red&style=flat-square"></a>
<a href="https://www.gnu.org/software/bash/"><img src="https://img.shields.io/badge/bash-v5-brightgreen?style=flat-square&logo" alt="Bash v5"></a>
  <a href="https://github.com/pacstall/pacstall/issues"><img src="https://img.shields.io/github/issues/pacstall/pacstall?style=flat-square"></a>
<a href="https://github.com/pacstall/pacstall/actions?query=workflow%3A%22test+install+script%22"><img src="https://img.shields.io/github/workflow/status/pacstall/pacstall/test%20install%20script?style=flat-square"></a>
<a href="https://www.codefactor.io/repository/github/pacstall/pacstall"><img src="https://img.shields.io/codefactor/grade/github/pacstall/pacstall/develop?style=flat-square"></a>
<a href="https://discord.gg/yzrjXJV6K8"><img src="https://img.shields.io/discord/839818021207801878?style=flat-square"></a>
</p>

<p align="center"><b>PACSTALL</b></p>
<p align="center">
<a href="https://github.com/pacstall/pacstall"><img align="center" src="website-images/pacstall.png" alt="Pacstall Logo"></a>
</p>
<p align="center"><b>The AUR Ubuntu never had</b></p>

<p align="center">Pacstall will attempt to become the AUR Ubuntu wishes it had. It takes the AUR and puts a spin on it, making it easier to install programs without scouring github repos and the likes</p>
</p>

---

### Installing

You can grab the deb file [here](https://github.com/pacstall/pacstall/releases/latest) although they aren't as up to date as running one of the commands below. If that's not your thing you can run this command:
```bash
sudo bash -c "$(curl -fsSL https://git.io/JsADh || wget -q https://git.io/JsADh -O -)"
```
---

## Basic Commands

```bash
sudo pacstall -I foo
``` 
This will install foo. Equivalent of apt install

```bash
sudo pacstall -R foo
```
This will remove foo. Equivalent of apt remove

```bash
sudo pacstall -S foo
```
This will search for foo in repositories. Equivalent of apt search

```bash
sudo pacstall -C
```
This will open a window where you can choose a repository

```bash
sudo pacstall -U
```
This will update pacstall's scripts

```bash
sudo pacstall -Up
```

This will update packages. Equivalent of apt upgrade

These are the basic commands, for more info, run `pacstall -h`
#### Misc
##### Zsh auto completion
Zsh can emulate bash completion scripts by default so all you have to do is add these to your `.zshrc` or wherever you source things:
```bash
autoload bashcompinit
bashcompinit
source /usr/share/bash-completion/completions/pacstall
```
