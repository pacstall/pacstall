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
    safeenv="$(sudo mktemp -p "${PACDIR}")"
    sudo chmod +r "$safeenv"
    bwrapenv="$(sudo mktemp -p "${PACDIR}" -t "bwrapenv.XXXXXXXXXX")"
    sudo chmod +r "$bwrapenv"
    export bwrapenv
    export safeenv

    tmpfile="$(sudo mktemp -p "${PACDIR}")"
    echo "#!/bin/bash -a" | sudo tee "$tmpfile" > /dev/null
    { 
        echo "mapfile -t __OLD_ENV < <(compgen -A variable  -P \"--unset \")"
        echo "readonly __OLD_ENV"
        echo "source \"${input}\""
        # /bin/env returns variables and functions, with values, so we sed them out
        echo "mapfile -t NEW_ENV < <(/bin/env -0 \${__OLD_ENV[@]} | \
            sed -ze 's/BASH_FUNC_\(.*\)%%=\(.*\)$/\n/g;s/^\(.[[:alnum:]_]*\)=\(.*\)$/\1/g'|tr '\0' '\n')"
        # The env sourced inside of bwrap should contain everything from the pacscripts
        echo "declare -p \${NEW_ENV[@]} >> \"${bwrapenv}\""
        echo "declare -pf >> \"${bwrapenv}\""
        # The Pacstall env should only receive the bare minimum of information needed
        echo "echo > \"${safeenv}\""

        # Any new variables or functions should be added here in the future
        echo "for i in {pkgname,repology,pkgver,git_pkgver,epoch,source_url,source,depends,makedepends,conflicts,breaks,replaces,gives,pkgdesc,hash,optdepends,ppa,arch,maintainer,pacdeps,patch,PACPATCH,NOBUILDDEP,provides,incompatible,compatible,optinstall,srcdir,url,backup,pkgrel,mask,pac_functions,repo,priority,noextract,nosubmodules,_archive,license,external_connection}; do \
                [[ -z \"\${!i}\" ]] || declare -p \$i >> \"${safeenv}\"; \
            done"
        echo "[[ \$name == *'-deb' ]] || for i in {parse_source_entry,calc_git_pkgver,post_install,post_remove,post_upgrade,pre_install,pre_remove,pre_upgrade,prepare,build,check,package}; do \
                [[ \$(type -t \"\$i\") == \"function\" ]] && declare -pf \$i >> \"${safeenv}\"; \
            done || true"
    } | sudo tee -a "$tmpfile" > /dev/null
    sudo chmod +x "$tmpfile"

    sudo env - bwrap --unshare-ipc --unshare-pid --unshare-uts \
        --unshare-cgroup --die-with-parent --new-session --ro-bind / / \
        --proc /proc --dev /dev --tmpfs /tmp --tmpfs /run --dev-bind /dev/null /dev/null \
        --ro-bind "$input" "$input" --bind "$PACDIR" "$PACDIR" --ro-bind "$tmpfile" "$tmpfile" \
        --setenv homedir "$homedir" --setenv CARCH "$CARCH" --setenv DISTRO "$DISTRO" --setenv NCPU "$NCPU" \
        --setenv PACSTALL_USER "$PACSTALL_USER" \
    "$tmpfile" && sudo rm "$tmpfile"
}

function bwrap_function() {
    local func="$1"
    tmpfile="$(sudo mktemp -p "${PWD}")"
    echo "#!/bin/bash -a" | sudo tee "$tmpfile" > /dev/null
    {
        echo "mapfile -t OLD_ENV < <(compgen -A variable  -P \"--unset \")"
        echo "source ${bwrapenv}"
        # Run function, save env changes, exit with status
        echo "$func 2>&1 \"${LOGDIR}/$(printf '%(%Y-%m-%d_%T)T')-$name-$func.log\" && FUNCSTATUS=\"\${PIPESTATUS[0]}\" && \
            if [[ \$FUNCSTATUS ]]; then \
                mapfile -t NEW_ENV < <(/bin/env -0 \${OLD_ENV[@]} | \
                    sed -ze 's/BASH_FUNC_\(.*\)%%=\(.*\)$/\n/g;s/^\(.[[:alnum:]_]*\)=\(.*\)$/\1/g'|tr '\0' '\n'); \
                declare -p \${NEW_ENV[@]} >> \"${bwrapenv}\"; \
            fi && exit \$FUNCSTATUS"
    } | sudo tee -a "$tmpfile" > /dev/null
    sudo chmod +x "$tmpfile"

    fancy_message sub "Running $func"
    if [[ ! -d ${LOGDIR} ]]; then
        sudo mkdir -p "${LOGDIR}"
    fi
    sudo bwrap --unshare-ipc --unshare-pid --unshare-uts \
        --unshare-cgroup --die-with-parent --new-session --ro-bind / / \
        --proc /proc --dev /dev --tmpfs /tmp --tmpfs /run --dev-bind /dev/null /dev/null \
        --bind "$STOWDIR" "$STOWDIR" --bind "$PACDIR" "$PACDIR" \
        --setenv LOGDIR "$LOGDIR" --setenv STGDIR "$STGDIR" \
        --setenv STOWDIR "$STOWDIR" --setenv pkgdir "$pkgdir" \
        --setenv _archive "$_archive" --setenv srcdir "$srcdir" \
    "$tmpfile" && sudo rm "$tmpfile"
}

# vim:set ft=sh ts=4 sw=4 noet:
