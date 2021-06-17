# Contributing

*  Make it meaningful
Don't make a random flag that serves edge cases, make flags that can be used by many people

*  Make it functional
I know my code can be sloppy (working on it), but please document code. If your code is a big function, put it in misc/scripts/ and source it from a flag in pacstall. If it is small it can stay in the pacstall file

> “Always code as if the guy who ends up maintaining your code will be a violent psychopath who knows where you live”
>
> -- <cite>John Woods</cite>

We use [git flow](https://github.com/petervanderdoes/gitflow-avh) to manage pacstall. Make sure that you are familiar with it before attempting to make changes

First, indents need to be like so:
```bash
#!/bin/bash
test=true
if [[ -n $test ]]; then
    echo "It works"
fi
```

Two, when possible (almost always), format variables like this:
```bash
#!/bin/bash
var="foo bar baz"
echo "$var"
```
Note the quotes after `echo`

Next is to use pacstall's built in functions when possible. [Look here](https://github.com/pacstall/pacstall-programs/blob/master/technical-side.md#apis-i-guess) for more info
