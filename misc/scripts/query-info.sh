#!/bin/bash

if [[ -z "$PACKAGE" ]]; then
  fancy_message error "You failed to specify a package"
  exit 1
fi

if [ ! -f "$LOGDIR/$PACKAGE" ]; then
  fancy_message error "Package does not exist"
  exit 1
fi

source "$LOGDIR/$PACKAGE"
echo "${BGreen}name${NORMAL}: $PACKAGE"
echo "${BGreen}version${NORMAL}: $_version"
echo "${BGreen}size${NORMAL}: $(du -sh "$STOWDIR"/"$PACKAGE" 2> /dev/null | awk '{print $1}')"
echo "${BGreen}description${NORMAL}: ""$_description"""
echo "${BGreen}date installed${NORMAL}: ""$_date"""

if [[ -n $_maintainer ]]; then
  echo "${BGreen}maintainer${NORMAL}: ""$_maintainer"""
fi
if [[ -n $_pacdeps ]]; then
  echo "${BGreen}pacstall dependencies${NORMAL}: ""$_pacdeps"""
fi
if [[ -n $_dependencies ]]; then
  echo "${BGreen}dependencies${NORMAL}: ""$_dependencies"""
fi
if [[ -n $_build_dependencies ]]; then
  echo "${BGreen}build dependencies${NORMAL}: ""$_build_dependencies"""
fi
if [[ -n $_pacstall_depends ]]; then
  echo "${BGreen}install type${NORMAL}: installed as dependency"
else
  echo "${BGreen}install type${NORMAL}: explicitly installed"
fi
exit 0
