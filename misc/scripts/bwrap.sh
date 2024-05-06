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
    mkdir /tmp/pacstall 2> /dev/null
    safeenv="$(sudo mktemp -p "${PACDIR}")"
    sudo chmod +r "$safeenv"
    bwrapenv="$(sudo mktemp -p "${PACDIR}" -t "bwrapenv.XXXXXXXXXX")"
    sudo chmod +r "$bwrapenv"
    export bwrapenv
    export safeenv

    tmpfile="$(sudo mktemp -p "${PACDIR}")"
    local allvar src sum a_sum allvar_str pacfunc_str debfunc_str \
        known_hashsums_src=("b2" "sha512" "sha384" "sha256" "sha224" "sha1" "md5") \
        known_archs_src=("amd64" "arm64" "armel" "armhf" "i386" "mips64el" "ppc64el" "riscv64" "s390x") \
        allvars=("pkgname" "repology" "pkgver" "git_pkgver" "epoch" "source_url" "source" "depends" "makedepends" "checkdepends"
            "conflicts" "breaks" "replaces" "gives" "pkgdesc" "hash" "optdepends" "ppa" "arch" "maintainer" "pacdeps" "patch"
            "PACPATCH" "NOBUILDDEP" "provides" "incompatible" "compatible" "optinstall" "srcdir" "url" "backup" "pkgrel" "mask"
            "pac_functions" "repo" "priority" "noextract" "nosubmodules" "_archive" "license" "external_connection") \
        pacstall_funcs=("prepare" "build" "check" "package") \
        debian_funcs=("post_install" "post_remove" "post_upgrade" "pre_install" "pre_remove" "pre_upgrade")
    for src in "${known_archs_src[@]}"; do
        for vars in {source,depends,makedepends,optdepends,pacdeps,checkdepends,provides,conflicts,breaks,replaces,gives}; do
            allvars+=("${vars}_${src}")
        done
    done
    for sum in "${known_hashsums_src[@]}"; do
        allvars+=("${sum}sums")
        for a_sum in "${known_archs_src[@]}"; do
            allvars+=("${sum}sums_${a_sum}")
        done
    done
    for allvar in "${allvars[@]}" "${pacstall_funcs[@]}" "${debian_funcs[@]}"; do
        unset "${allvar}"
    done
    IFS=,
    allvar_str="${allvars[*]}"
    unset IFS
    IFS=,
    pacfunc_str="${pacstall_funcs[*]}"
    unset IFS
    IFS=,
    debfunc_str="${debian_funcs[*]}"
    unset IFS

    sudo tee "$tmpfile" > /dev/null << EOF
#!/bin/bash -a
mapfile -t __OLD_ENV < <(compgen -A variable  -P "--unset ")
readonly __OLD_ENV
$(declare -pf def_colors) && def_colors
$(for i in {ask,fancy_message,parse_source_entry,calc_git_pkgver}; do declare -pf "${i}"; done)
source "${input}"
mapfile -t NEW_ENV < <(/bin/env -0 \${__OLD_ENV[@]} | \
    sed -ze 's/BASH_FUNC_\(.*\)%%=\(.*\)\$/\n/g;s/^\(.[[:alnum:]_]*\)=\(.*\)\$/\1/g'|tr '\0' '\n')
declare -p \${NEW_ENV[@]} >> "${bwrapenv}"
declare -pf >> "${bwrapenv}"
echo > "${safeenv}"
for i in {${allvar_str}}; do
    if [[ -n "\${!i}" ]]; then
        declare -p \$i >> "${safeenv}";
        declare -p \$i >> "${bwrapenv}";
    fi
done
[[ \$pkgname == *'-deb' ]] && for i in {${debfunc_str}}; do
    [[ \$(type -t "\$i") == "function" ]] && declare -pf \$i >> "${safeenv}";
done || for i in {${debfunc_str},${pacfunc_str}}; do
    [[ \$(type -t "\$i") == "function" ]] && declare -pf \$i >> "${safeenv}";
done
export safeenv
EOF
    sudo chmod +x "$tmpfile"

    sudo env - bwrap --unshare-all --die-with-parent --new-session --ro-bind / / \
        --proc /proc --dev /dev --tmpfs /tmp --tmpfs /run --dev-bind /dev/null /dev/null \
        --ro-bind "$input" "$input" --bind "$PACDIR" "$PACDIR" --ro-bind "$tmpfile" "$tmpfile" \
        --setenv homedir "$homedir" --setenv CARCH "$CARCH" --setenv DISTRO "$DISTRO" --setenv NCPU "$NCPU" \
        --setenv PACSTALL_USER "$PACSTALL_USER" \
        "$tmpfile" && sudo rm "$tmpfile"
}

function bwrap_function() {
    local func="$1"
    tmpfile="$(sudo mktemp -p "${PWD}")"
    sudo tee -a "$tmpfile" > /dev/null << EOF
#!/bin/bash -a
mapfile -t OLD_ENV < <(compgen -A variable -P "--unset ")
source ${bwrapenv}
${func} 2>&1 "${LOGDIR}/$(printf '%(%Y-%m-%d_%T)T')-$name-$func.log" && FUNCSTATUS="\${PIPESTATUS[0]}" && \
if [[ \$FUNCSTATUS ]]; then \
    mapfile -t NEW_ENV < <(/bin/env -0 \${OLD_ENV[@]} | \
        sed -ze 's/BASH_FUNC_\(.*\)%%=\(.*\)\$/\\n/g;s/^\\(.[[:alnum:]_]*\\)=\\(.*\\)\$/\\1/g'|tr '\0' '\n'); \
    declare -p \${NEW_ENV[@]} >> "${bwrapenv}"; \
fi && exit \$FUNCSTATUS
EOF
    sudo chmod +x "$tmpfile"

    fancy_message sub "Running $func"
    if [[ ! -d ${LOGDIR} ]]; then
        sudo mkdir -p "${LOGDIR}"
    fi
    local share_net
    if [[ ${external_connection} == "true" ]]; then
        share_net="--share-net"
    fi
    sudo bwrap --unshare-all ${share_net} --die-with-parent --new-session --ro-bind / / \
        --proc /proc --dev /dev --tmpfs /tmp --tmpfs /run --dev-bind /dev/null /dev/null \
        --bind "$STAGEDIR" "$STAGEDIR" --bind "$PACDIR" "$PACDIR" --setenv LOGDIR "$LOGDIR" \
        --setenv SCRIPTDIR "$SCRIPTDIR" --setenv STAGEDIR "$STAGEDIR" --setenv pkgdir "$pkgdir" \
        --setenv _archive "$_archive" --setenv srcdir "$srcdir" --setenv git_pkgver "$git_pkgver" \
        --setenv homedir "$homedir" --setenv CARCH "$CARCH" --setenv DISTRO "$DISTRO" --setenv NCPU "$NCPU" \
        --setenv PACSTALL_USER "$PACSTALL_USER" \
        "$tmpfile" && sudo rm "$tmpfile"
}

# vim:set ft=sh ts=4 sw=4 noet:
