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

"""Pacstall logging API."""

from datetime import datetime
from logging import (
    DEBUG,
    ERROR,
    INFO,
    WARNING,
    Formatter,
    LogRecord,
    StreamHandler,
    basicConfig,
    getLogger,
)
from pathlib import Path
from shutil import rmtree
from time import time

from pacstall.api.color import Foreground as Fg
from pacstall.api.color import Style as St


class ConsoleFormatter(Formatter):
    """
    Special Pacstall console formatter.

    Attributes
    ----------
    FORMATS : dict of str
        The logging formats for each level.

    Methods
    -------
    format(record)
        Format logging message.
    """

    FORMATS = {
        DEBUG: f"{St.DIM}[#] DEBUG: %(message)s{St.RESET}",
        INFO: f"[{Fg.BGREEN}+{St.RESET}] {St.BOLD}INFO{St.RESET}: %(message)s",
        WARNING: f"[{Fg.BYELLOW}*{St.RESET}] {St.BOLD}WARNING{St.RESET}: %(message)s",
        ERROR: f"[{Fg.BRED}!{St.RESET}] {St.BOLD}ERROR{St.RESET}: %(message)s",
    }
    """
    The logging formats for each level.
    """

    def format(self, record: LogRecord) -> str:
        """
        Format logging message.

        Parameters
        ----------
        record : LogRecord
            A LogRecord instance represents an event being logged.

        Returns
        -------
        str
            The formatted logging message.
        """

        self._style._fmt = self.FORMATS[record.levelno]
        record.exc_text = (
            record.exc_info
        ) = None  # --> Disable exception logging in console.
        return Formatter.format(self, record)


def setup_logger(
    file_logger_level: int = DEBUG,
    console_logger_level: int = INFO,
    lifetime: float = time() - 7 * 86_400,
) -> None:
    """
    Sets up the logger. Only run this once.

    Parameters
    ----------
    file_logger_level : int
        The logging level of the file logger.
    console_logger_level : int
        The logging level of the console logger.
    lifetime : float
        The lifetime of old log files, before they are purged.
    """

    LOGGING_DIR_PREFIX = Path("/var/log/pacstall/")
    LOGGING_DIR_PREFIX.mkdir(exist_ok=True, parents=True)

    # Delete older logs
    for log_folder in LOGGING_DIR_PREFIX.glob("*"):
        log_folder_lifetime = log_folder.stat().st_mtime
        if log_folder_lifetime < lifetime:
            rmtree(log_folder)

    today = datetime.today()
    # Create logging path objects
    logging_dir_path = LOGGING_DIR_PREFIX / f"{today.date()}"
    logging_dir_path.mkdir(exist_ok=True)
    logging_file_path = logging_dir_path / f"{today.time()}.log"

    # Configure file logger
    basicConfig(
        level=file_logger_level,
        format="%(asctime)s %(name)-12s %(levelname)-8s %(message)s",
        datefmt="%r",
        filename=logging_file_path,
        filemode="w",
    )

    # Add console logger
    console = StreamHandler()
    console.setLevel(console_logger_level)
    console.setFormatter(ConsoleFormatter())
    getLogger().addHandler(console)
