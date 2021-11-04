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

from api import message

import os
from getpass import getuser
from sys import exit
from glob import glob
from time import time

if getuser() == "root":
    message.fancy("error", "Pacstall can't be run as root")
    exit(1)

# Run `sudo apt update` if sources haven't been updated for more than a week
if not [
    list
    for list in glob("/var/lib/apt/lists/*")
    if os.stat(list).st_mtime < time() - 604800
]:
    message.fancy("info", "Last update was more than one week ago")
    message.fancy("info", "Updating system")
    os.system("sudo apt-get -qq update")
