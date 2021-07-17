#!/bin/bash

function fn_exists() {
  declare -F "$1" > /dev/null;
}


source "/var/cache/pacstall/$PACKAGE/$_version/$PACKAGE.pacscript"

case "$url" in
*.deb)
sudo apt remove "$gives" 2>/dev/null
if [[ $? -eq 0 ]]; then
exit 0
else
fancy_message warn "Failed to remove the package"
exit 1
fi
;;

*)
cd "$STOWDIR" || (sudo mkdir -p "$STOWDIR"; cd "$STOWDIR")

# Run preliminary checks
if [[ -z "$PACKAGE" ]]; then
  fancy_message error "You failed to specify a package"
  exit 1
fi

if [[ ! -d "$PACKAGE" ]]; then
  fancy_message error "$PACKAGE is not installed or not properly symlinked"
  exit 1
fi

# Removal starts from here
source "$LOGDIR/$PACKAGE" > /dev/null 2>&1

fancy_message info "Removing symlinks"
sudo stow --target="/" -D "$PACKAGE"

fancy_message info "Removing package"
sudo rm -rf "$PACKAGE"
# Update PATH database
hash -r

if fn_exists removescript ; then
    fancy_message info "Running post removal script"
    REPO=$(cat "$STGDIR/repo/pacstallrepo.txt")
    removescript
fi

if [ -n "$_dependencies" ]; then
  fancy_message info "You may want to remove ${BLUE}$_dependencies${NC}"
fi

sudo rm -f "$LOGDIR/$PACKAGE"
exit 0
;;
esac

exit
