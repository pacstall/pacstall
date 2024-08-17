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

if [[ -z $PACKAGE ]]; then
    fancy_message error $"You failed to specify a package"
    exit 1
fi

if [[ ! -f "$METADIR/$PACKAGE" ]]; then
    fancy_message error $"Package is not installed"
    exit 1
fi

source "$METADIR/$PACKAGE"

function get_field() {
    # shellcheck disable=SC2034
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    # input 1: package
    # input 2: field
    # input 3: out_var
    local input="${_gives:-$_name}"
    local -n out_var="${3:?}"
    local output="$(dpkg-query --showformat="\${$2}\n" --show "$input")"
    if [[ -n $output ]]; then
        out_var="${output}"
    fi
}

get_field "$PACKAGE" Package name
if [[ -n ${_pkgbase} ]]; then
    base="${_pkgbase}"
fi
get_field "$PACKAGE" Version version
if [[ -n ${_install_size} ]]; then
    size="${_install_size}"
fi
get_field "$PACKAGE" Description description
date_installed="${_date}"
if [[ -n ${_homepage} ]]; then
    homepage="${_homepage}"
fi
get_field "$PACKAGE" License license
if [[ -n ${_remoterepo} ]]; then
    remote_repo="${_remoterepo}"
fi
license="${license//,/}"
get_field "$PACKAGE" Maintainer maintainer
if [[ -n ${_ppa} ]]; then
    ppa="${_ppa}"
fi
if [[ -n ${_pacdeps} ]]; then
    pacstall_dependencies="${_pacdeps[*]}"
fi
get_field "$PACKAGE" Depends deps
deps="${deps//,/}"
if [[ -n ${deps} ]]; then
    dependencies="${deps}"
fi
if [[ -n ${_pacstall_depends} ]]; then
    install_type="installed as dependency"
else
    install_type="explicitly installed"
fi
get_field "$PACKAGE" Modified-By-Pacstall mbp
if [[ ${mbp} != "yes" ]]; then
    mbp="no"
fi
if [[ -n ${_mask[*]} ]]; then
    mask="${_mask[*]}"
fi

if [[ -n ${QUERY} ]]; then
    query="${!QUERY}"
    if [[ -z ${query} ]]; then
        fancy_message error $"Key '${QUERY}' does not exist"
        exit 1
    else
        echo "${query}"
        exit 0
    fi
fi

echo -e "${BGreen}name${NC}: ${name}"
if [[ -v base ]]; then
    echo -e "${BGreen}base${NC}: ${base}"
fi
echo -e "${BGreen}version${NC}: ${version}"
if [[ -v size ]]; then
    echo -e "${BGreen}size${NC}: ${size}"
fi
echo -e "${BGreen}description${NC}: ${description}"
echo -e "${BGreen}date installed${NC}: ${date_installed}"

if [[ -v homepage ]]; then
    echo -e "${BGreen}homepage${NC}: ${homepage}"
fi
if [[ -n ${license} ]]; then
    echo -e "${BGreen}license${NC}: ${license}"
fi
if [[ -v remote_repo ]]; then
    echo -e "${BGreen}remote repo${NC}: ${remote_repo}"
fi
if [[ -v mask ]]; then
    echo -e "${BGreen}mask${NC}: ${mask}"
fi
echo -e "${BGreen}maintainer${NC}: ${maintainer}"
if [[ -v ppa ]]; then
    echo -e "${BGreen}ppa${NC}: ${ppa}"
fi
if [[ -v pacstall_dependencies ]]; then
    echo -e "${BGreen}pacstall dependencies${NC}: ${pacstall_dependencies}"
fi
if [[ -v dependencies ]]; then
    echo -e "${BGreen}dependencies${NC}: ${dependencies}"
fi
echo -e "${BGreen}install type${NC}: ${install_type}"
if [[ ${PACKAGE} == *"-deb" ]]; then
    echo -e "${BGreen}modified by pacstall${NC}: ${mbp}"
fi
exit 0
# vim:set ft=sh ts=4 sw=4 et:
