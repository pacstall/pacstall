#!/bin/env python3

#     ____                  __        ____
#    / __ \____ ___________/ /_____ _/ / /
#   / /_/ / __ `/ ___/ ___/ __/ __ `/ / /
#  / ____/ /_/ / /__(__  ) /_/ /_/ / / /
# /_/    \__,_/\___/____/\__/\__,_/_/_/
#
# Copyright (C) 2020-2021
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

from urllib.request import urlopen
from pacstall.api.message import fancy, ask
from pacstall.cmd.repos import get_repos


def partial_match(package,package_list):
    # To do
    return []


def print_results(package,match_dict):
    print("To do")


def choose(package,repo_dict):
    ask("To do","Y")
    return list(repo_dict.values())[0] # To do


def search(package, match=False):

    repo_dict=get_repos()
    repo = None

    if "@" in package:
        pkg_name, repo = package.split("@",1)

        try:
            with urlopen(f'{repo_dict[repo]}/packagelist') as list_file:
                packagelist = list_file.read().decode('utf-8').split()
        except KeyError:
            fancy("error", "Repo provided is not on the repo list")
            return -1

        if pkg_name in packagelist:
            return f'{repo_url}/packages/{pkg_name}/{pkg_name}.pacscript'

        fancy("error", f"Package {pkg_name} not found in the repo provided")
        return -1
    
    if match:
        match_list = []
        for repo in repo_dict:
            with urlopen(f'{repo_dict[repo]}/packagelist') as list_file:
                packagelist = list_file.read().decode('utf-8').split()
            
            if pkg_name in packagelist:
                match_list.append(f'repo_url/packages/{package}/{package}.pacscript')

        if match_list:
            return choose(package,match_list)
        
        fancy("error", f"Package {pkg_name} not found")
        return -1

    match_dict = {}
    for repo in repo_dict:
        with urlopen(f'{repo_dict[repo]}/packagelist') as list_file:
            packagelist = list_file.read().decode('utf-8').split()
        
        for pkg in partial_match(package,packagelist):
            if repo in match_dict:
                match_dict[repo]+=[pkg]
            match_dict[repo]=[pkg]

    print_results(package, match_dict)
    return 0
            