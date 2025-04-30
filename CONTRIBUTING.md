<!--
    ____                  __        ____
   / __ \____ ___________/ /_____ _/ / /
  / /_/ / __ `/ ___/ ___/ __/ __ `/ / /
 / ____/ /_/ / /__(__  ) /_/ /_/ / / /
/_/    \__,_/\___/____/\__/\__,_/_/_/

Copyright (C) 2020-present

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
* Always test your patch with [shellcheck](https://github.com/koalaman/shellcheck) before submitting a pull request.

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
We generally don't use tabs.

Use `tabstop` = 4, `shiftwidth` = 4, and `expandtab`

*Also read [Vim Modeline](#vim-modeline)*

---

#### Quotes

Always use double quotes `""`.
```bash
var="foo bar baz"
echo "$var"
```

---

#### Commits

We use this style of commit messages.
```monospace
Type (scope): Subject

body

footer
```

##### Types

* `feat`: A new feature.
* `fix`: A bug fix.
* `docs`: Changes to documentation.
* `style`: Formatting etc; no code change.
* `ref`: Refactoring code.
* `test`: Adding tests, refactoring test; no production code change.

##### Scopes

* `main`: Changes to the main file ( `pacstall` ).
* `installer`: Changes to the installer ( `install.sh` ).
* `completion`: Changes to the completion files ( `misc/completion `).
* `scripts`: Changes to the scripts ( `misc/scripts` ).
* `github`: Changes to GitHub specific files ( `.github` etc ).
* Your own scope if you feel your changes don't fall under the aforementioned scopes.

##### Subject

Subjects should be no greater than 50 characters, should begin with a capital letter and do not end with a period.

Use an imperative tone to describe what a commit does, rather than what it did. For example, use change; not changed or changes.

##### Body

Not all commits are complex enough to warrant a body, therefore it is optional and only used when a commit requires a bit of explanation and context.

##### Footer

The footer is optional and is used to reference issue tracker IDs.

#### Pull Requests

##### Title of pull request

Pull request titles should be structured like the commit messages, but the `Subject` portion should be a single high-level description of all the changes in it.

##### Draft pull requests

All pull requests should start as drafts, only mark them ready for review when you think they are.

### Boilerplate

#### Shebang
Always place the shebang at the start of the files.
`#!/bin/bash`

#### GPL boilerplate
Paste this boilerplate in the beginning of every file.
```monospace
    ____                  __        ____
   / __ \____ ___________/ /_____ _/ / /
  / /_/ / __ `/ ___/ ___/ __/ __ `/ / /
 / ____/ /_/ / /__(__  ) /_/ /_/ / / /
/_/    \__,_/\___/____/\__/\__,_/_/_/

Copyright (C) 2020-present

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
vim:set ft=sh ts=4 sw=4 et:
```

This automatically sets the `filetype`(`= sh`), `tabstop`(`= 4`), and `shiftwidth`(`= 4`), and most importantly enables `expandtab`.

If your editor is not vim, then make sure your tab settings are as above.

[modeline]: # ( vim:set ft=markdown ts=4 sw=4 et: )
