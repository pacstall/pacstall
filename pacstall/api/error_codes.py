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

"""Defines error codes used in Pacstall."""

from enum import IntFlag


class PacstallError(Exception):
    """
    Used to raise Pacstall related errors.
    """

    def __init__(self, code: int) -> None:
        super().__init__()
        self.code = code


class ErrorCodes(IntFlag):
    """
    Contains error codes used  in Pacstall.

    Based on the ``sysexits.h`` standard header.
    """

    USAGE_ERROR = 64
    """
    The command was used incorrectly, e.g., with the wrong number of arguments,
    a bad flag, a bad syntax in a parameter, or whatever.
    """

    DATA_ERROR = 65
    """
    The input data was incorrect in some way. This should only be used for
    user's data and not system files.
    """

    NO_INPUT_ERROR = 66
    """An input file (not a system file) did not exist or was not readable."""

    NO_USER_ERROR = 67
    """
    The user specified did not exist. This might be used for mail addresses or
    remote logins.
    """

    NO_HOST_ERROR = 68
    """
    The host specified did not exist. This is used in mail addresses or network
    requests.
    """

    UNAVAILABLE_ERROR = 69  # Nice!
    """
    A service is unavailable. This can occur if a support program or file does
    not exist. This can also be used as a catch-all message when something you
    wanted to do does not work, but you do not know why.
    """

    SOFTWARE_ERROR = 70
    """
    An internal software error has been detected. This should be limited to
    non-operating system related errors as possible.
    """

    OS_ERROR = 71
    """
    An operating system error has been detected. This is intended to be used for
    such things as "cannot fork", "cannot create pipe", or the like. It includes
    things like ``getuid`` returning a user that does not exist in the
    ``passwd`` file.
    """

    OS_FILE_ERROR = 72
    """
    Some system file (e.g., ``/etc/passwd``, ``/var/run/utx.active``, etc.)
    does not exist, cannot be opened, or has some sort of error (e.g., syntax
    error).
    """

    CANT_CREATE_ERROR = 73
    """A (user specified) output file cannot be created."""

    IO_ERROR = 74
    """An error occurred while doing I/O on some file."""

    TEMP_FAIL_ERROR = 75
    """Temporary failure, indicating something that is not really an error."""

    PROTOCOL_ERROR = 76
    """
    The remote system returned something that was "not possible" during a
    protocol exchange.
    """

    NO_PERM_ERROR = 77
    """
    You did not have sufficient permission to perform the operation. This is not
    intended for file system problems, which should use ``NO_INPUT_ERROR`` or
    ``CANT_CREATE_ERROR``, but rather for higher level permissions.
    """

    CONFIG_ERROR = 78
    """Something was found in an unconfigured or misconfigured state."""
