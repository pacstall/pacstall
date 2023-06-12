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

export LOGDIR="/var/log/pacstall/metadata"

function dep_tree.has_deps() {
    local le_pkg="${1:?No pkg given to dep_tree.has_deps}"
    if [[ -n $(dpkg-query '--showformat=${Depends}\n' --show "${le_pkg}") ]]; then
        return 0
    else
        return 1
    fi
}

function dep_tree.load_traits() {
    local pkg
    local -n out_arr
    local -n pacdeps
    pkg="${1:?No pkg given to dep_tree.load_traits}"
    out_arr="${2:?No arr given to dep_tree.load_traits}"
    pacdeps="${3:?No pacdeps arr given to dep_tree.load_traits}"
    unset -n _pacstall_depends _pacdeps 2> /dev/null
    source "${LOGDIR}/${pkg}"

    if [[ -n ${_pacstall_depends} ]]; then
        out_arr['upgrade']=false
    else
        out_arr['upgrade']=true
    fi
    if [[ -n ${_pacdeps[*]} ]]; then
        out_arr['pacdeps']=true
        pacdeps+=("${_pacdeps[@]}")
    else
        out_arr['pacdeps']=false
    fi
    if dep_tree.has_deps "${_gives:-${_name}}"; then
        out_arr['depends']=true
    else
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

    if [[ ${trait['pacdeps']} == 'false' && ${trait['depends']} == 'false' ]]; then
        c_one+=("${pkg}")
    elif [[ ${trait['pacdeps']} == 'true' && ${trait['depends']} == 'false' ]]; then
        c_two+=("${pkg}")
    else
        c_three+=("${pkg}")
    fi
}

function dep_tree.loop_traits() {
    local -n merged_array="${1:?No array given to dep_tree.loop_traits}"
    shift
    local class_one=() class_two=() class_three=() pacdeps_arr=() i
    for i in "${@}"; do
        echo -n "Loading traits of ${i}"
        local -A arr=()
        dep_tree.load_traits "$i" arr pacdeps_arr
        dep_tree.sort_traits_into_array "$i" arr class_one class_two class_three
        echo -ne "\033[2K\rParsed ${i}"
    done
    echo -ne "\033[2K\r"
    merged_array=("${class_one[@]}" "${class_two[@]}" "${class_three[@]}")
    # Remove all pacdeps logged
    if ((${#pacdeps_arr[@]} > 0)); then
        local idx=0
        for pacdep in "${pacdeps_arr[@]}"; do
            for j in "${merged_array[@]}"; do
                if [[ ${j} == "${pacdep}" ]]; then
                    unset 'merged_array[idx]'
                fi
                ((idx++))
            done
        done
		merged_array=("${merged_array[@]}")
    fi
}

dep_tree.loop_traits update_order $(pacstall -L)
declare -p update_order
