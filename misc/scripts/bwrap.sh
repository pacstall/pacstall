#!/bin/bash

#     ____                  __        ____
#    / __ \____ ___________/ /_____ _/ / /
#   / /_/ / __ `/ ___/ ___/ __/ __ `/ / /
#  / ____/ /_/ / /__(__  ) /_/ /_/ / / /
# /_/    \__,_/\___/____/\__/\__,_/_/_/
#
# Copyright (C) 2020-present
#
# This file is part of Pacstall
#
# Pacstall is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3 of the License
#
# Pacstall is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Pacstall. If not, see <https://www.gnu.org/licenses/>.

function safe_source() {
    local input="${1}"
    mkdir /tmp/pacstall 2>/dev/null
    safeenv="$(sudo mktemp -p "${SRCDIR}")"
    sudo chmod +r "$safeenv"
    bwrapenv="$(sudo mktemp -t "${SRCDIR}/bwrapenv.XXXXXXXXXX")"
    sudo chmod +r "$bwrapenv"
    export bwrapenv

    tmpfile="$(sudo mktemp -p "${SRCDIR}")"
    echo "#!/bin/bash -ae" | sudo tee "$tmpfile" > /dev/null
    echo "mapfile -t __OLD_ENV < <(compgen -A variable  -P \"--unset \")" | sudo tee -a "$tmpfile" > /dev/null
    echo "readonly __OLD_ENV" | sudo tee -a "$tmpfile" > /dev/null
    echo "source \"${input}\"" | sudo tee -a "$tmpfile" > /dev/null
    # /bin/env returns variables and functions, with values, so we sed them out
    echo "mapfile -t NEW_ENV < <(/bin/env -0 \${__OLD_ENV[@]} | \
        sed -ze 's/BASH_FUNC_\(.*\)%%=\(.*\)$/\n/g;s/^\(.[[:alnum:]_]*\)=\(.*\)$/\1/g'|tr '\0' '\n')" | sudo tee -a "$tmpfile" > /dev/null
    # The env sourced inside of bwrap should contain everything from the pacscripts
    echo "declare -p \${NEW_ENV[@]} >> \"${bwrapenv}\"" | sudo tee -a "$tmpfile" > /dev/null
    echo "declare -pf >> \"${bwrapenv}\"" | sudo tee -a "$tmpfile" > /dev/null
    # The Pacstall env should only receive the bare minimum of information needed
    echo "echo > \"${safeenv}\"" | sudo tee -a "$tmpfile" > /dev/null
    echo "for i in {name,repology,pkgver,epoch,url,depends,makedepends,breaks,replace,gives,pkgdesc,hash,optdepends,ppa,arch,maintainer,pacdeps,patch,provides,incompatible,optinstall,epoch,homepage,backup,pkgrel,mask,external_connection}; do \
            [[ -z \"\${!i}\" ]] || declare -p \$i >> \"${safeenv}\"; \
        done" | sudo tee -a "$tmpfile" > /dev/null
    echo "[[ \$name == *'-deb' ]] || for i in {pkgver,post_install,post_remove,pre_install,prepare,build,package}; do \
            [[ \$(type -t \"\$i\") == \"function\" ]] && declare -pf \$i >> \"${safeenv}\"; \
        done || true" | sudo tee -a "$tmpfile" > /dev/null
    sudo chmod +x "$tmpfile"

    sudo env - bwrap --unshare-all --die-with-parent --new-session --ro-bind / / \
        --proc /proc --dev /dev --tmpfs /tmp --tmpfs /run --dev-bind /dev/null /dev/null \
        --ro-bind "$input" "$input" --bind "$SRCDIR" "$SRCDIR" --ro-bind "$tmpfile" "$tmpfile" \
        --setenv homedir "$homedir" --setenv CARCH "$CARCH" --setenv DISTRO "$DISTRO" --setenv NCPU "$NCPU" \
    "$tmpfile" && sudo rm "$tmpfile"
    source "$safeenv"
    sudo rm "$safeenv"
}

function bwrap_pkgver() {
    tmpfile="$(sudo mktemp -p "${PWD}")"
    echo "#!/bin/bash -e" | sudo tee "$tmpfile" > /dev/null
    echo "source ${bwrapenv}" | sudo tee -a "$tmpfile" > /dev/null
    echo "pkgver" | sudo tee -a "$tmpfile" > /dev/null
    sudo chmod +rx "$tmpfile"

    sudo env - bwrap --unshare-all --share-net --die-with-parent --new-session --ro-bind / /   \
        --proc /proc --dev /dev --tmpfs /tmp --dev-bind /dev/null /dev/null \
        --ro-bind "$bwrapenv" "$bwrapenv" --ro-bind "$tmpfile" "$tmpfile" \
        "$tmpfile" && sudo rm "$tmpfile"
}

function bwrap_function() {
    local func="$1"
    tmpfile="$(sudo mktemp -p "${PWD}")"
    echo "#!/bin/bash -a" | sudo tee "$tmpfile" > /dev/null
    echo "mapfile -t OLD_ENV < <(compgen -A variable  -P \"--unset \")" | sudo tee -a "$tmpfile" > /dev/null
    echo "source ${bwrapenv}" | sudo tee -a "$tmpfile" > /dev/null
    # Run function, save env changes, exit with status
    echo "$func 2>&1 \"${LOGDIR}/$(printf '%(%Y-%m-%d_%T)T')-$name-$func.log\" && FUNCSTATUS=\"\${PIPESTATUS[0]}\" && \
        if [[ \$FUNCSTATUS ]]; then \
            mapfile -t NEW_ENV < <(/bin/env -0 \${OLD_ENV[@]} | \
                sed -ze 's/BASH_FUNC_\(.*\)%%=\(.*\)$/\n/g;s/^\(.[[:alnum:]_]*\)=\(.*\)$/\1/g'|tr '\0' '\n'); \
            declare -p \${NEW_ENV[@]} >> \"${bwrapenv}\"; \
        fi && exit \$FUNCSTATUS" | sudo tee -a "$tmpfile" > /dev/null
    sudo chmod +x "$tmpfile"

    fancy_message sub "Running $func"
    if [[ ! -d ${LOGDIR} ]]; then
        sudo mkdir -p "${LOGDIR}"
    fi
    local share_net
    if [[ ${external_connection} == "true" ]]; then
        share_net="--share-net"
    fi
    sudo bwrap --unshare-all $share_net --die-with-parent --new-session --ro-bind / / \
        --proc /proc --dev /dev --tmpfs /tmp --tmpfs /run --dev-bind /dev/null /dev/null \
        --bind "$STOWDIR" "$STOWDIR" --bind "$SRCDIR" "$SRCDIR" \
        --setenv LOGDIR "$LOGDIR" --setenv STGDIR "$STGDIR" \
        --setenv STOWDIR "$STOWDIR" --setenv pkgdir "$pkgdir" \
        "$tmpfile"
    sudo rm "$tmpfile"
}

# vim:set ft=sh ts=4 sw=4 noet:
