<!--
    ____                  __        ____
   / __ \____ ___________/ /_____ _/ / /
  / /_/ / __ `/ ___/ ___/ __/ __ `/ / /
 / ____/ /_/ / /__(__  ) /_/ /_/ / / /
/_/    \__,_/\___/____/\__/\__,_/_/_/

Copyright (C) 2020-2021

This file is part of Pacstall

Pacstall is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License

Pacstall is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Pacstall. If not, see <https://www.gnu.org/licenses/>.
-->

# Contributing

> “Always code as if the guy who ends up maintaining your code will be a violent psychopath who knows where you live”
>
> — <cite>John Woods</cite>

## Requirements

* This project follows the [GitFlow paradigm](https://jointcenterforsatellitedataassimilation-jedi-docs.readthedocs-hosted.com/en/latest/inside/practices/gitflow.html), make sure you are familiar with it.
* Have knowledge of [bash v5](https://www.gnu.org/software/bash)
* Check out the [existing issues](https://github.com/pacstall/pacstall/issues) & [pull requests](https://github.com/pacstall/pacstall/pulls) before making a contribution.

---

## Code Guidelines

### Style

#### Placements

##### `do`, `then` and `in` placement
We think starting writing them on the same line is the superior method. Please follow that.
```bash
for i in 1 2 3 4 5; do
	echo "$i"
done
```
```bash
if true; then
	echo "true"
done
```
```bash
case expression in
	case1)
		echo "case1"
	;;
	case2)
		echo "case2"
	;;
esac
```

##### `;;` placement for each `case`
We think placing `;;` directly under each case is the superior method. Please follow that.
```bash
case expression in
	case1)
		echo "case1"
	;;
	case2)
		echo "case2"
	;;
esac
```

---

#### Tabs vs Spaces
We use tabs. Period. Only exception is in ASCII art.

---

### Quotes

Always use double quotes `""`
```bash
var="foo bar baz"
echo "$var"
```

---

### Boilerplate

#### Shebang
Always place the shebang at the start of the files.
`#!/bin/env bash`

#### GPL boilerplate
Paste this boilerplate in the beginning of every file.
```monospace
    ____                  __        ____
   / __ \____ ___________/ /_____ _/ / /
  / /_/ / __ `/ ___/ ___/ __/ __ `/ / /
 / ____/ /_/ / /__(__  ) /_/ /_/ / / /
/_/    \__,_/\___/____/\__/\__,_/_/_/

Copyright (C) 2020-2021

This file is part of Pacstall

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

#### Vim Modeline
Paste this modeline at the end of each file.
```monospace
vim:set ft=sh ts=4 sw=4 noet:
```

This automatically sets the `filetype`(`= sh`), `tabstop`(`= 4`), and `shiftwidth`(`= 4`), and most importantly disables `expandtab`

If your editor is not vim, then make sure your tab settings are as above.

[modeline]: # ( vim:set ft=markdown ts=4 sw=4 noet: )
