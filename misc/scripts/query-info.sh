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
echo -e "${BGreen}name${NORMAL}: $PACKAGE"
echo -e "${BGreen}version${NORMAL}: $_version"
echo -e "${BGreen}size${NORMAL}: $(du -sh "$STOWDIR"/"$PACKAGE" 2> /dev/null | awk '{print $1}')"
echo -e "${BGreen}description${NORMAL}: ""$_description"""
echo -e "${BGreen}date installed${NORMAL}: ""$_date"""

if [[ -n $_remoterepo ]]; then
  echo -e "${BGreen}remote repo${NORMAL}: ""$_remoterepo"""
fi
if [[ -n $_maintainer ]]; then
  echo -e "${BGreen}maintainer${NORMAL}: ""$_maintainer"""
fi
if [[ -n $_ppa ]]; then
  echo -e "${BGreen}ppa${NORMAL}: ""$_ppa"""
fi
if [[ -n $_pacdeps ]]; then
  echo -e "${BGreen}pacstall dependencies${NORMAL}: ""$_pacdeps"""
fi
if [[ -n $_dependencies ]]; then
  echo -e "${BGreen}dependencies${NORMAL}: ""$_dependencies"""
fi
if [[ -n $_build_dependencies ]]; then
  echo -e "${BGreen}build dependencies${NORMAL}: ""$_build_dependencies"""
fi
if [[ -n $_pacstall_depends ]]; then
  echo -e "${BGreen}install type${NORMAL}: installed as dependency"
else
  echo -e "${BGreen}install type${NORMAL}: explicitly installed"
fi
exit 0
