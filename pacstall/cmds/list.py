#     ____                  __        ____
#    / __ \____ ___________/ /_____ _/ / /
#   / /_/ / __ `/ ___/ ___/ __/ __ `/ / /
#  / ____/ /_/ / /__(__  ) /_/ /_/ / / /
# /_/    \__,_/\___/____/\__/\__,_/_/_/
#
# Copyright (C) 2020-2022
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

"""List command."""

from pathlib import Path

from pacstall.cmds import app

LOGDIR = "/var/log/pacstall/metadata"


# It is a bad idea to overwite the list built-in function in Python, which
# converts a variable to a list. Python will shadow the namespace to
# compensate.
@app.command()
def list() -> None:
    """List installed packages."""

    metadata = Path(LOGDIR)

    def list_map_func(pathobj) -> tuple:
        version = None
        with pathobj.open() as fp:
            for line in fp:
                if line.startswith('_version='):
                    version = line.split('=')[1].strip()[1:-1]
        return (pathobj.name, version)

    version_list = sorted(map(list_map_func, metadata.iterdir()))

    for pkg, ver in version_list:
        print(f'{pkg}, {ver}')
