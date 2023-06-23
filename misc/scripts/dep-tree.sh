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

# The order we prefer is pkgs with only pacdeps (class 1), pacdeps+deps (class 2), everything else (class 3)
# If the pkg has _pacstall_depends, then we should always consider it not upgradable, and let `-I` handle it

function dep_tree.has_deps() {
    local le_pkg="${1:?No pkg given to dep_tree.has_deps}"
    if [[ -n $(dpkg-query '--showformat=${Depends}\n' --show "${le_pkg}") ]]; then
        return 0
    else
        return 1
    fi
}

function dep_tree.has_pacdeps() {
    local pkg="${1:?No pkg given to dep_tree.has_pacdeps}"
    local deps i
    mapfile -t -d' ' deps < <(dpkg-query '--showformat=${Depends}\n' --show "${pkg}" 2> /dev/null | awk NF | tr -d ',')
    if ((${#deps[@]} == 0)); then
        return 1
    fi
    for i in "${deps[@]}"; do
        if dep_tree.is_section_pacstall "${i}"; then
            return 0
        fi
    done
    return 1
}

function dep_tree.load_traits() {
    local pkg
    local -n out_arr
    pkg="${1:?No pkg given to dep_tree.load_traits}"
    out_arr="${2:?No arr given to dep_tree.load_traits}"
    unset _pacstall_depends _pacdeps _name _version _install_date _date _ppa _homepage _gives _remoterepo _remotebranch 2> /dev/null
    source "${LOGDIR}/${pkg}"

    if [[ -n ${_pacstall_depends} ]]; then
        out_arr['upgrade']=false
    else
        out_arr['upgrade']=true
    fi
    if [[ -n ${_pacdeps[*]} ]]; then
        out_arr['pacdeps']=true
    else
        out_arr['pacdeps']=false
    fi
    if dep_tree.has_deps "${_gives:-${_name}}"; then
        out_arr['depends']=true
    else
        # shellcheck disable=SC2034
        out_arr['depends']=false
    fi
}

function dep_tree.sort_traits_into_array() {
    local pkg="${1:?No pkg given to dep_tree.sort_traits_into_array}"
    local -n trait c_one c_two c_three
    local trait="${2:?No trait array given to dep_tree.sort_traits_into_array}"
    c_one="${3:?No c_one array given to dep_tree.sort_traits_into_array}"
    c_two="${4:?No c_two array given to dep_tree.sort_traits_into_array}"
    c_three="${5:?No c_three array given to dep_tree.sort_traits_into_array}"

    if [[ ${trait['upgrade']} == 'false' ]]; then
        return 0
    fi

    if [[ ${trait['pacdeps']} == 'true' ]]; then
        c_one+=("${pkg}")
    elif [[ ${trait['depends']} == 'false' ]]; then
        c_two+=("${pkg}")
    else
        c_three+=("${pkg}")
    fi
}

function dep_tree.loop_traits() {
    local -n merged_array="${1:?No array given to dep_tree.loop_traits}"
    shift
    local class_one=() class_two=() class_three=() i
    for i in "${@}"; do
        # shellcheck disable=SC2034
        local -A arr=()
        dep_tree.load_traits "$i" arr
        unset _pacstall_depends _pacdeps 2> /dev/null
        dep_tree.sort_traits_into_array "$i" arr class_one class_two class_three
    done
    # shellcheck disable=SC2034
    merged_array=("${class_one[@]}" "${class_two[@]}" "${class_three[@]}")
}
