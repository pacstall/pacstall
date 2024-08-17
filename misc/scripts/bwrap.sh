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

{ ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }

function safe_source() {
    # shellcheck disable=SC2034
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local input="${1}"
    mkdir -p "${PACDIR}" 2> /dev/null
    tmpfile="$(sudo mktemp -p "${PACDIR}")"
    local allvar_str pacfunc_str debfunc_str pacstall_funcs=("prepare" "build" "check" "package") \
    debian_funcs=("post_install" "post_remove" "post_upgrade" "pre_install" "pre_remove" "pre_upgrade")
    for allvar in "${pacstallvars[@]}" "${pacstall_funcs[@]}" "${debian_funcs[@]}"; do
        unset "${allvar}"
    done
    IFS=,
    allvar_str="${pacstallvars[*]}"
    pacfunc_str="${pacstall_funcs[*]}"
    debfunc_str="${debian_funcs[*]}"
    unset IFS

    safeenv="$(sudo mktemp -p "${PACDIR}")"
    sudo chmod +r "$safeenv"
    bwrapenv="$(sudo mktemp -p "${PACDIR}" -t "bwrapenv.XXXXXXXXXX")"
    sudo chmod +r "$bwrapenv"
    export bwrapenv
    export safeenv

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
[[ \$pacname == *'-deb' ]] && for i in {${debfunc_str}}; do
    [[ \$(type -t "\$i") == "function" ]] && declare -pf \$i >> "${safeenv}";
done || for i in {${debfunc_str},${pacfunc_str}}; do
    [[ \$(type -t "\$i") == "function" ]] && declare -pf \$i >> "${safeenv}";
    if [[ -n \$pkgbase && \$i == "package" ]]; then
        for p in "\${pkgname[@]}"; do
            [[ \$(type -t "\${i}_\${p}") == "function" ]] && declare -pf "\${i}_\${p}" >> "${safeenv}";
        done
    fi
done
export safeenv
EOF
    sudo chmod +x "$tmpfile"
    if [[ ${NOSANDBOX} == "true" ]]; then
        sudo homedir="${homedir}" CARCH="${CARCH}" AARCH="${AARCH}" DISTRO="${DISTRO}" CDISTRO="${CDISTRO}" NCPU="${NCPU}" PACSTALL_USER="${PACSTALL_USER}" \
            "$tmpfile" && sudo rm "$tmpfile"
    else
        sudo env - bwrap --unshare-all --die-with-parent --new-session --ro-bind / / \
            --proc /proc --dev /dev --tmpfs /tmp --tmpfs /run --dev-bind /dev/null /dev/null \
            --ro-bind "$input" "$input" --bind "$PACDIR" "$PACDIR" --ro-bind "$tmpfile" "$tmpfile" \
            --setenv homedir "$homedir" --setenv CARCH "$CARCH" --setenv AARCH "$AARCH" --setenv DISTRO "$DISTRO" \
            --setenv CDISTRO "$CDISTRO" --setenv NCPU "$NCPU" --setenv PACSTALL_USER "$PACSTALL_USER" \
            "$tmpfile" && sudo rm "$tmpfile"
    fi
}

function bwrap_function() {
    # shellcheck disable=SC2034
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
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
fi && ignore_stack=true && exit \$FUNCSTATUS
EOF
    sudo chmod +x "$tmpfile"

    fancy_message sub $"Running $func"
    if [[ ! -d ${LOGDIR} ]]; then
        sudo mkdir -p "${LOGDIR}"
    fi
    local share_net dns_resolve
    if [[ ${external_connection} == "true" ]]; then
        share_net="--share-net"
        if [[ -d "/run/systemd/resolve" ]]; then
            dns_resolve="--ro-bind /run/systemd/resolve /run/systemd/resolve"
        fi
    fi
    if [[ ${NOSANDBOX} == "true" ]]; then
        sudo LOGDIR="${LOGDIR}" SCRIPTDIR="${SCRIPTDIR}" STAGEDIR="${STAGEDIR}" pkgdir="${pkgdir}" _archive="${_archive}" \
            srcdir="${srcdir}" git_pkgver="${git_pkgver}" homedir="${homedir}" CARCH="${CARCH}" AARCH="${AARCH}" \
            DISTRO="${DISTRO}" CDISTRO="${CDISTRO}" NCPU="${NCPU}" PACSTALL_USER="${PACSTALL_USER}" TAR_OPTIONS='--no-same-owner' \
            "$tmpfile" && sudo rm "$tmpfile"
    else
        # shellcheck disable=SC2086
        sudo bwrap --unshare-all ${share_net} --die-with-parent --new-session \
            --ro-bind / / --proc /proc --dev /dev --tmpfs /tmp --tmpfs /run ${dns_resolve} \
            --dev-bind /dev/null /dev/null --tmpfs /root --tmpfs /home --setenv safeenv "$safeenv" \
            --bind "$STAGEDIR" "$STAGEDIR" --bind "$PACDIR" "$PACDIR" --setenv LOGDIR "$LOGDIR" \
            --setenv SCRIPTDIR "$SCRIPTDIR" --setenv STAGEDIR "$STAGEDIR" --setenv pkgdir "$pkgdir" \
            --setenv _archive "$_archive" --setenv srcdir "$srcdir" --setenv git_pkgver "$git_pkgver" \
            --setenv homedir "$homedir" --setenv CARCH "$CARCH" --setenv AARCH "$AARCH" --setenv DISTRO "$DISTRO" \
            --setenv CDISTRO "$CDISTRO"  --setenv NCPU "$NCPU" --setenv PACSTALL_USER "$PACSTALL_USER" --setenv TAR_OPTIONS '--no-same-owner' \
            "$tmpfile" && sudo rm "$tmpfile"
    fi
}

# vim:set ft=sh ts=4 sw=4 et:
