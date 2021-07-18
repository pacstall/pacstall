#!/usr/bin/env fish

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

set -l pacstall_commands -I -S -R -C -U -V -L -Up -Qd -Qi -D
complete -f --command pacstall -n "not __fish_seen_subcommand_from $pacstall_commands" -a -I -d 'Install package'
complete -f --command pacstall -n "not __fish_seen_subcommand_from $pacstall_commands" -a -S -d 'Search for package'
complete -f --command pacstall -n "not __fish_seen_subcommand_from $pacstall_commands" -a -R -d 'Remove package'
complete -f --command pacstall -n "not __fish_seen_subcommand_from $pacstall_commands" -a -C -d 'Change repository'
complete -f --command pacstall -n "not __fish_seen_subcommand_from $pacstall_commands" -a -U -d 'Update pacstall scripts'
complete -f --command pacstall -n "not __fish_seen_subcommand_from $pacstall_commands" -a -V -d 'Print pacstall version'
complete -f --command pacstall -n "not __fish_seen_subcommand_from $pacstall_commands" -a -L -d 'List packages installed'
complete -f --command pacstall -n "not __fish_seen_subcommand_from $pacstall_commands" -a -Up -d 'Upgrade packages'
complete -f --command pacstall -n "not __fish_seen_subcommand_from $pacstall_commands" -a -Qd -d 'Query the dependencies of a package'
complete -f --command pacstall -n "not __fish_seen_subcommand_from $pacstall_commands" -a -Qi -d 'Get package info'
complete -f --command pacstall -n "not __fish_seen_subcommand_from $pacstall_commands" -a -D -d 'Downloads package'

# Completion for the -I flag
complete -f --command pacstall -n "__fish_seen_subcommand_from -I" -a "(curl -s https://raw.githubusercontent.com/pacstall/pacstall-programs/master/packagelist | tr ' ' '\n')"

# Completion for the -S flag
complete -f --command pacstall -n "__fish_seen_subcommand_from -S" -a "(curl -s https://raw.githubusercontent.com/pacstall/pacstall-programs/master/packagelist | tr ' ' '\n')"

# Completion for the -R flag
complete -f --command pacstall -n "__fish_seen_subcommand_from -R" -a "(/bin/ls -1aA /usr/src/pacstall/ | tr ' ' '\n')"

# Completion for the -Qi flag
complete -f --command pacstall -n "__fish_seen_subcommand_from -Qi" -a "(/bin/ls -1aA /var/log/pacstall | tr ' ' '\n')"

# Completion for the -D flag
complete -f --command pacstall -n "__fish_seen_subcommand_from -D" -a "(curl -s https://raw.githubusercontent.com/pacstall/pacstall-programs/master/packagelist | tr ' ' '\n')"
