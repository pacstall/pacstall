#!/bin/bash

if ask "Are you sure you want to update pacstall?" Y; then
  for i in {add-repo.sh,search.sh,download.sh,install-local.sh,upgrade.sh,remove.sh,update.sh,query-info.sh}}; do
    sudo wget -q -N https://raw.githubusercontent.com/"$USERNAME"/pacstall/"$BRANCH"/misc/scripts/"$i" -P "$STGDIR/scripts" 2> /dev/null 
  done

  sudo wget -q -N https://raw.githubusercontent.com/"$USERNAME"/pacstall/"$BRANCH"/pacstall -P /bin 2> /dev/null
  sudo mkdir -p /usr/share/bash-completion/completions
  sudo wget -q -O /usr/share/bash-completion/completions/pacstall https://raw.githubusercontent.com/"$USERNAME"/pacstall/"$BRANCH"/misc/completion/bash 2> /dev/null

  if command -v fish &> /dev/null; then
    sudo wget -q -O /usr/share/fish/vendor_completions.d/pacstall.fish https://raw.githubusercontent.com/"$USERNAME"/pacstall/"$BRANCH"/misc/completion/fish 2> /dev/null
  fi

# Bling Bling update ascii
echo '
    ____                  __        ____
   / __ \____ ___________/ /_____ _/ / /
  / /_/ / __ `/ ___/ ___/ __/ __ `/ / /
 / ____/ /_/ / /__(__  ) /_/ /_/ / / /
/_/    \__,_/\___/____/\__/\__,_/_/_/
'
  fancy_message info "You are at version $(pacstall -V)"
  fancy_message warn "Be sure to check our GitHub release page to make sure you have no incompatible code: https://github.com/$USERNAME/pacstall/tree/$BRANCH"

  echo "$USERNAME $BRANCH" | sudo tee "$STGDIR/repo/update" > /dev/null
  exit 0
else
  exit 1
fi
