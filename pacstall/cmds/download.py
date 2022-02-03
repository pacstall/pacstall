#!/bin/env python3

"""Download command."""

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

from asyncio import gather
from logging import getLogger
from pathlib import Path
from typing import List

import aiofiles
from httpx import AsyncClient, HTTPStatusError, RequestError
from rich import print as rprint
from rich.progress import (
    BarColumn,
    Progress,
    SpinnerColumn,
    TaskID,
    TextColumn,
    TimeRemainingColumn,
    TransferSpeedColumn,
)
from rich.table import Column

from pacstall.api.error_codes import ErrorCodes


async def download(
    client: AsyncClient,
    url: str,
    download_task: TaskID,
    progress_bar: Progress,
) -> int:
    """
    Downloads URLs asynchronously.

    Parameters
    ----------
    client
        The asynchronous httpx client.
    url
        The URL to download.
    download_task
        The task ID of the download task. Used to update the progress bar.
    progress_bar
        The progress bar.

    Returns
    -------
    int
        Exit codes (return codes) depending on the status of the download.
        - ``0`` for success.
        - :atrr:`pacstall.ErrorCodes.UNAVAILABLE_ERROR` (69) for when there's a
          :exc:`HTTPStatusError` or :exc:`RequestError`.
        - :atrr:`ErrorCodes.IO_ERROR` for when there's an :exc:`OSError`.
    """
    filename = url.split("/")[-1].split(".pacscript")[0]

    # TODO: `log.debug` each successfully downloaded file.
    #       If verbose level is high enough.
    try:
        response = await client.get(url)
        response.raise_for_status()
        async with aiofiles.open(Path.cwd() / url.split("/")[-1], mode="wb") as file:
            await file.write(response.content)

        progress_bar.update(download_task, advance=1, filename=filename)

        return 0

    except HTTPStatusError as error:
        rprint(
            f"[bold red]Failed[/bold red]: {filename} (HTTP status error: {error.response.status_code})"
        )
        log = getLogger()
        log.debug(f"Failed: {filename}", exc_info=True)
        return ErrorCodes.UNAVAILABLE_ERROR

    except RequestError as error:
        error_message = str(error) or type(error).__name__
        rprint(f"[bold red]Failed[/bold red]: {filename} ({error_message})")

        log = getLogger()
        log.debug(f"Failed: {filename}", exc_info=True)
        return ErrorCodes.UNAVAILABLE_ERROR

    except OSError as error:
        error_message = str(error) or type(error).__name__
        rprint(f"[bold red]Failed[/bold red]: {filename} (OS error: {error_message})")

        log = getLogger()
        log.debug(f"Failed: {filename}", exc_info=True)
        return ErrorCodes.IO_ERROR


async def execute(pacscripts: List[str]) -> int:
    """
    Executes the download command.

    Parameters
    ----------
    pacscripts
        The pacscripts to download.

    Returns
    -------
    int
        Returns the greatest returned exit code from :func:`download`

    See Also
    --------
    download : Asynchronous download function for the pacscript URLs.

    Notes
    -----
    This function currently only supports downloading pacscripts from the
    `official repository <https://github.com/pacstall/pacstall-programs>`_.
    """
    # TODO: Add ability to download from other repositories.
    urls = {
        f"https://raw.githubusercontent.com/pacstall/pacstall-programs/master/packages/{pacscript}/{pacscript}.pacscript"
        for pacscript in pacscripts
    }

    with Progress(
        SpinnerColumn(finished_text="[bold green]:heavy_check_mark:"),
        TextColumn(
            "[bold blue]{task.fields[filename]}",
            # Make the column width the average width of the pacscripts
            table_column=Column(
                width=round(
                    sum(len(pacscript) for pacscript in pacscripts) / len(pacscripts)
                )
            ),
        ),
        BarColumn(bar_width=None),
        "[magenta]{task.completed}/{task.total}",
        TransferSpeedColumn(),
        TimeRemainingColumn(),
        auto_refresh=True,
    ) as progress_bar:

        download_task = progress_bar.add_task(
            "download pacscripts",
            total=len(urls),
            filename=pacscripts[0],
        )
        async with AsyncClient(follow_redirects=True) as client:
            return max(  # type: ignore[no-any-return]
                await gather(
                    *[
                        download(
                            client,
                            url,
                            download_task,
                            progress_bar,
                        )
                        for url in urls
                    ]
                )
            ).real
