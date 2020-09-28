## Repos

Tl;DR

1: A github repo

2: A directory inside of that repo called `packages`

3: A `complete` file (for autocompleting package names)


### Long way
Assuming you've already made an empty repository, make a new directory called packages, inside of that will follow this easy structure: `foo/foo.pacscript`.
For every package added to your repo, edit the file called `complete` in the root directory of your repo. Every package added will have the name of the package (foo) appended to it. That way, the end user can tab autocomplete package names.
