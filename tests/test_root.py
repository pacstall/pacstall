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

from os import environ
from subprocess import run
from pathlib import Path


def test_launch_as_root():
    # Run the help command as root
    process = run(
        [
            "sudo",
            "-E",
            f"{Path(environ['HOME']) / '.local/bin/poetry'}",
            "run",
            "pacstall",
            "-h",
        ]
    )
    assert process.returncode == 0


def test_launch_as_normal_user():
    # Run the help command as normal user
    process = run(["poetry", "run", "pacstall", "-h"])
    assert process.returncode == 1
