#!/bin/bash

if [[ -z "$PACKAGE" ]]; then
  fancy_message error "You failed to specify a package"
  exit 1
fi

if [ ! -f "$LOGDIR/installed/$PACKAGE" ]; then
  fancy_message error "Package does not exist"
  exit 1
fi

source "$LOGDIR/installed/$PACKAGE"
echo "name: $PACKAGE"
echo "version: $_version"
echo "size: $(du -sh "$STOWDIR"/"$PACKAGE" 2> /dev/null | awk '{print $1}')"
echo "description: ""$_description"""
echo "date installed: ""$_date"""

if [[ -n $_maintainer ]]; then
  echo "maintainer: ""$_maintainer"""
fi
if [[ -n $_pacdeps ]]; then
  echo "pacstall dependencies: ""$_pacdeps"""
fi
if [[ -n $_dependencies ]]; then
  echo "dependencies: ""$_dependencies"""
fi
if [[ -n $_build_dependencies ]]; then
  echo "build dependencies: ""$_build_dependencies"""
fi
if [[ -n $_pacstall_depends ]]; then
  echo "install type: installed as dependency"
else
  echo "install type: explicitly installed"
fi
exit 0
