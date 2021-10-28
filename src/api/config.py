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

import tempfile

LOGDIR = "/var/log/pacstall"  # Logging directory
STGDIR = "/usr/share/pacstall"  # Scripts storage directory
STOWDIR = "/usr/src/pacstall"  # Stowing directory

# SRCDIR -> Package source code storage dir
def SRCDIR() -> str:
    """Securely generate a SRCDIR to store source code of packages."""
    return tempfile.mkdtemp()
