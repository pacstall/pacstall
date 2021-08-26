#!/bin/env python3

#     ____                  __        ____
#    / __ \____ ___________/ /_____ _/ / /
#   / /_/ / __ `/ ___/ ___/ __/ __ `/ / /
#  / ____/ /_/ / /__(__  ) /_/ /_/ / / /
# /_/	 \__,_/\___/____/\__/\__,_/_/_/
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

import os
from sys import exit
from shutil import chown, which
from socket import create_connection
from requests import get
from subprocess import Popen, PIPE
from multiprocessing import cpu_count
from concurrent.futures import ThreadPoolExecutor

# Colors
NC = "\033[0m"

RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"

BIGreen = "\033[1;92m"
BIRed = "\033[1;91m"


class Msg:
    """
    Pacstall's messaging API

    Methods
    -------
    fancy (type, message): Print fancy messages
    ask (question, default="nothing"): Ask Y/N questions
    """

    @classmethod
    def fancy(cls, type: str, message: str) -> None:
        """
        Print fancy messages

        Parameters
        ----------
        type (str): Type of message - "info" or "warn" or "error".
        message (str): Message.
        """

        # type: prompt
        types = {
            "info": f"[{GREEN}+{NC}] INFO:",
            "warn": f"[{YELLOW}*{NC}] WARNING:",
            "error": f"[{RED}!{NC}] ERROR:",
        }
        prompt = types.get(type, f"[?] UNKNOWN:")
        print(f"{prompt} {message}")

    @classmethod
    def ask(cls, question: str, default: str = "nothing") -> str:
        """
        Ask Y/N questions

        Parameters
        ----------
        question (str): Question.
        default="nothing" (str): Default option - "Y" or "N" or nothing.

        Returns
        -------
        str: Returns the user's reply

        """
        # default: prompt
        defaults = {
            "Y": f"{BIGreen}Y{NC}/{RED}n{NC}",
            "N": f"{GREEN}y{NC}/{BIRed}N{NC}",
        }

        prompt = defaults.get(default, f"{GREEN}y{NC}/{RED}n{NC}")
        reply = input(f"{question} [{prompt}] ").upper()

        if not reply:
            reply = default

        while True:
            if reply == "Y" or reply == "N":
                return reply
            else:
                reply = input(f"{question} [{prompt}] ").upper()


def download(url: str, filepath: str = os.getcwd()) -> None:
    """
    Download files from the internet

    Parameters
    ----------
    url (str): URL of the file
    filepath=os.getcwd() (str): Location of the local file
    """
    data = get(url)
    if not data.status_code == 200:
        Msg.fancy("error", f"Error occurred while downloading {url}")
        Msg.fancy("error", f"Error code: {data.status_code}")
    else:
        with open(filepath, "wb") as file:
            file.write(data.content)


print(
    f"""|------------------------|
|---{GREEN}Pacstall Installer{NC}---|
|------------------------|
"""
)

if not which("apt"):
    Msg.fancy("error", "apt is not installed")
    exit(1)

try:
    # connect to the host -- tells us if the host is actually
    # reachable
    with create_connection(("www.github.com", 80)) as sock:
        pass
except OSError:
    Msg.fancy("error", "Can't reach github. Check your internet connection")
    exit(1)

if not Popen(
    "find -H /var/lib/apt/lists -maxdepth 0 -mtime -7",
    shell=True,
    stdout=PIPE,
).stdout:
    Msg.fancy("info", "Last update was more than one week ago")
    Msg.fancy("info", "Updating system")
    os.system("sudo apt-get -qq update")


Msg.fancy("info", "Installing optional dependencies")

if Msg.ask("Do you want to install axel (faster downloads)? ", "Y") == "Y":
    Msg.fancy("info", "Installing axel...")
    os.system("sudo apt-get -y install axel > /dev/null")
    Msg.fancy("info", "Done!")

if Msg.ask("Do you want to install ripgrep (faster searches)? ", "Y") == "Y":
    Msg.fancy("info", "Installing ripgrep...")
    os.system("sudo apt-get -y install ripgrep > /dev/null")

Msg.fancy("info", "Done!")
Msg.fancy("info", "Proceeding with Pacstall installation")
Msg.fancy("info", "Installing dependencies...")

os.system(
    "sudo apt-get -y install sudo wget curl stow build-essential unzip tree bc fakeroot > /dev/null"
)
Msg.fancy("info", "Done!")


Msg.fancy("info", "Making directories...")
LOGDIR = "/var/log/pacstall"  # Logging directory
STGDIR = "/usr/share/pacstall"  # Storage directory for scripts
SRCDIR = "/tmp/pacstall"  # Building directory

os.makedirs(f"{STGDIR}/scripts", exist_ok=True)
os.makedirs(f"{STGDIR}/repo", exist_ok=True)

os.makedirs(SRCDIR, exist_ok=True)
chown(SRCDIR, os.getlogin())

os.makedirs(f"{LOGDIR}/metadata", exist_ok=True)
os.makedirs(f"{LOGDIR}/error_log", exist_ok=True)
chown(f"{LOGDIR}/error_log", os.getlogin())

os.makedirs("/usr/share/man/man8", exist_ok=True)
os.makedirs("/usr/share/bash-completion/completions", exist_ok=True)
os.makedirs("/usr/share/fish/vendor_completions.d", exist_ok=True)
Msg.fancy("info", "Done!")


Msg.fancy("info", "Resetting repositories...")
with open(f"{STGDIR}/repo/pacstallrepo.txt", "w") as repo_txt:
    repo_txt.write(
        "https://raw.githubusercontent.com/pacstall/pacstall-programs/master"
    )
Msg.fancy("info", "Done!")


Msg.fancy("info", "Downloading scripts...")
scripts = [
    "error_log.sh",
    "add-repo.sh",
    "search.sh",
    "download.sh",
    "install-local.sh",
    "upgrade.sh",
    "remove.sh",
    "update.sh",
    "query-info.sh",
]
with ThreadPoolExecutor(cpu_count()) as exe:
    result = exe.map(
        download,
        [
            f"https://raw.githubusercontent.com/pacstall/pacstall/master/misc/scripts/{script}"
            for script in scripts
        ],
        [[f"{STGDIR}/scripts/{script}" for script in scripts]],
    )

Msg.fancy("info", "Done!")


Msg.fancy("info", "Downloading Pacstall binary...")
download(
    "https://raw.githubusercontent.com/pacstall/pacstall/master/pacstall",
    "/bin/pacstall",
)
Msg.fancy("info", "Done!")


Msg.fancy("info", "Downloading man page...")
download(
    "https://raw.githubusercontent.com/pacstall/pacstall/master/misc/pacstall.8.gz",
    "/usr/share/man/man8/pacstall.8.gz",
)
Msg.fancy("info", "Done!")


Msg.fancy("info", "Downloading auto-completions...")
completions = ["bash", "fish"]
with ThreadPoolExecutor(cpu_count()) as exe:
    result = exe.map(
        download,
        [
            f"https://raw.githubusercontent.com/pacstall/pacstall/master/misc/completion/{completion}"
            for completion in completions
        ],
        [
            "/usr/share/bash-completion/completions/pacstall",
            "/usr/share/fish/vendor_completions.d/pacstall.fish",
        ],
    )
Msg.fancy("info", "Done!")


Msg.fancy("info", "Finishing up...")
os.chmod("/bin/pacstall", 0o755)

for script in os.listdir(f"{STGDIR}/scripts"):
    os.chmod(script, 0o755)
Msg.fancy("info", "Pacstall installation complete! Have a great day!")
