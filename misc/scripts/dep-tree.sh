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

# The order we prefer is only pacdeps, pacdeps+deps, everything else
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
	pkg="${1:?No pkg given to dep_tree.load_traits}"
	out_arr="${2:?No arr given to dep_tree.load_traits}"
	unset '_pacstall_depends' '_pacdeps' 2> /dev/null
	source "${LOGDIR}/${pkg}"
	if [[ -n ${_pacstall_depends} ]]; then
		out_arr['upgrade']=false
		return 0
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
		out_arr['depends']=false
	fi
}

while IFS= read -r i; do
	declare -A arr=()
	dep_tree.load_traits "$i" arr
	echo -n "Package $i: "
	declare -p arr
done < <(pacstall -L)
