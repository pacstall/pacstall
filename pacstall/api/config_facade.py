#!/bin/env python3

"""A facade for the `config.toml` file."""

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

from dataclasses import dataclass
from enum import Enum
from typing import Any, Dict, List, NoReturn, Optional, Tuple

import tomli
from requests import HTTPError, get

from pacstall.api.config import PACSTALL_CONFIG_PATH
from pacstall.api.error_codes import ErrorCodes
from pacstall.api.message import fancy


@dataclass
class RepositoryConfig:
    """
    Representation of a repository entry from `config.toml`
    """

    name: str
    url: str
    branch: str
    original_url: str


@dataclass
class SettingsConfig:
    """
    Data representation of the settings entry from `config.toml`
    """

    preferred_editor: Optional[str]


@dataclass
class PacstallConfig:
    """
    Data representation of `config.toml`
    """

    repositories: List[RepositoryConfig]
    settings: SettingsConfig


class SupportedGitProviderLinks(str, Enum):
    """
    String enum that contains the links of the officially supported git platforms
    """

    GITLAB_URL = "https://gitlab.com"
    GITHUB_URL = "https://github.com"
    BITBUCKET_URL = "https://bitbucket.org"


def is_repo_valid(repo_root_url: str) -> bool:
    """
    Checks if the the `repo_root_url` is valid.

    Parameters
    ----------
    repo_root_url (str): URL to the root of the raw repository.

    Returns
    -------
    `True` if the repository respects the file structure, otherwise `False`.
    """
    try:
        # Choose branch by checking if the `packagelist` file exists
        with get(f"{repo_root_url}/packagelist") as result:
            result.raise_for_status()
            return True
    except HTTPError:
        return False


def __parse_github_url(url: str) -> Optional[str]:
    """
    Parses GitHub url and returns a url to the root of the files.

    Parameters
    ----------
    url (str): URL to the root of the repository. Example: `https://github.com/pacstall/pacstall-programs`

    Returns
    -------
    Url to the root of the files or `None` if error.
    """

    githubRawUrl = "https://raw.githubusercontent.com"

    # If does not follow format `https://github.com/account/repository`
    if url.split(SupportedGitProviderLinks.GITHUB_URL)[1].count("/") != 2:
        return None

    return url.replace(SupportedGitProviderLinks.GITHUB_URL, githubRawUrl)


def __parse_gitlab_url(url: str) -> Optional[str]:
    """
    Parses GitLab url and returns a url to the root of the files.

    Parameters
    ----------
    url (str): URL to the root of the repository. Example: `https://github.com/pacstall/pacstall-programs`

    Returns
    -------
    Url to the root of the files or `None` if error.
    """

    # If does not follow format `https://gitlab.com/account/repository`
    if url.split(SupportedGitProviderLinks.GITLAB_URL)[1].count("/") != 2:
        return None

    return url + "/-/raw"


def __parse_bitbucket_url(url: str) -> Optional[str]:
    """
    Parses Bitbucket url and returns a url to the root of the files.

    Parameters
    ----------
    url (str): URL to the root of the repository. Example: `https://github.com/pacstall/pacstall-programs`

    Returns
    -------
    Url to the root of the files or `None` if error.
    """

    # If does not follow format `https://bitbucket.org/account/repository`
    if url.split(SupportedGitProviderLinks.BITBUCKET_URL)[1].count("/") != 2:
        return None

    return url + "/raw"


def parse_url(url: str) -> Optional[str]:
    """
    Tries to transform the given URL to a URL to the root of the raw git repository.

    Supported Git Providers
    -----------------------
    `GitHub`, `GitLab` and `BitBucket`

    Other Git Providers
    -------------------
    If the Git provider is not part of the list above, the URL is returned as-is.

    Returns
    -------
    The transformed URL if success, otherwise `None`
    """

    parsed_url: Optional[str] = url[:-1] if url.endswith("/") else url
    if url.startswith(SupportedGitProviderLinks.GITHUB_URL):
        parsed_url = __parse_github_url(url)
    elif url.startswith(SupportedGitProviderLinks.GITLAB_URL):
        parsed_url = __parse_gitlab_url(url)
    elif url.startswith(SupportedGitProviderLinks.BITBUCKET_URL):
        parsed_url = __parse_bitbucket_url(url)

    return parsed_url


def __raise_unreachable() -> NoReturn:
    """
    Small hack to help the type checker in complex cases.
    """
    raise Exception("Unreachable code. This will never be raised.")


def __parse_repo_config(
    conf_dict: Dict[str, Optional[Dict[str, Optional[Dict[str, Optional[str]]]]]]
) -> Tuple[Optional[List[RepositoryConfig]], Optional[ErrorCodes]]:
    """
    Maps config dict to RepositoryConfig

    Returns
    -------
    `(List[RepositoryConfig], None)` if success and `(None, ErrorCodes)` otherwise
    """

    parsed_repo_list: List[RepositoryConfig] = []
    repo_dict = conf_dict["repository"]
    if repo_dict is None:
        fancy("error", f"Config attribute 'repository' is required")
        return (None, ErrorCodes.CONFIG_ERROR)

    for (repo_name, repo_dict) in repo_dict.items():  # type: ignore[assignment]
        failed_validation = False
        if repo_dict["url"] is None:
            fancy("error", f"Config attribute '{repo_name}.url' is required")
            failed_validation = True
        if type(repo_dict["url"]) != str:  # type: ignore[comparison-overlap]
            fancy("error", f"Config attribute '{repo_name}.url' must be a string")
            failed_validation = True
        if repo_dict["branch"] is None:
            fancy("error", f"Config attribute '{repo_name}.branch' is required")
            failed_validation = True
        if type(repo_dict["branch"]) != str:  # type: ignore[comparison-overlap]
            fancy("error", f"Config attribute '{repo_name}.branch' must be a string")
            failed_validation = True

        if failed_validation:
            return (None, ErrorCodes.CONFIG_ERROR)

        url: str = repo_dict["url"]  # type: ignore[assignment]
        parsed_url: Optional[str] = parse_url(url)
        if parsed_url is None:
            fancy(
                "error",
                f"Repository '{repo_name}' has invalid attribute 'url': {url}",
            )
            return (None, ErrorCodes.CONFIG_ERROR)

        branch: str = repo_dict["branch"]  # type: ignore[assignment]
        repo_entry = RepositoryConfig(repo_name, parsed_url, branch, url)

        if not is_repo_valid(f"{repo_entry.url}/{repo_entry.branch}"):
            fancy(
                "error",
                f"File 'packagelist' not found in the '{repo_name}' repository root.",
            )
            return (None, ErrorCodes.NO_HOST_ERROR)

        parsed_repo_list.append(repo_entry)
    return (parsed_repo_list, None)


def __parse_settings_config(
    conf_dict: Dict[str, Optional[Dict[str, Optional[Any]]]]
) -> Tuple[Optional[SettingsConfig], Optional[ErrorCodes]]:
    """
    Maps config dict to SettingsConfig

    Returns
    -------
    `(SettingsConfig, None)` if success and `(None, ErrorCodes)` otherwise
    """

    if conf_dict["settings"] is None:
        fancy("error", f"Config attribute 'settings' is required")
        return (None, ErrorCodes.CONFIG_ERROR)

    if (
        conf_dict["settings"]["preferred_editor"] is not None
        and type(conf_dict["settings"]["preferred_editor"]) != str
    ):
        fancy("error", f"Config attribute 'settings.preferred_editor' must be a string")
        return (None, ErrorCodes.CONFIG_ERROR)

    editor = conf_dict["settings"].get("preferred_editor")

    return (SettingsConfig(preferred_editor=editor), None)


def read_config() -> Tuple[Optional[PacstallConfig], Optional[ErrorCodes]]:
    """
    Reads and parses the repository list.

    Returns
    -------
    A tuple consisting of the error code, and the repository list.
    If the error code is `None` then the repository list will *not* be `None` and vice-versa.
    """
    try:
        config_dict: Dict[str, Dict[str, Any]] = None  # type: ignore[assignment]
        try:
            with open(PACSTALL_CONFIG_PATH) as file:
                config_dict = tomli.load(file)  # type: ignore[arg-type]
        except OSError as error:
            fancy(
                "error",
                f"Could not read repositories from file '{PACSTALL_CONFIG_PATH}'.\n{error}",
            )

            return (None, ErrorCodes.NO_INPUT_ERROR)

        (repo_list, err) = __parse_repo_config(config_dict)  # type: ignore[arg-type]
        if err != None:
            return (None, err)

        (settingsConfig, err) = __parse_settings_config(config_dict)  # type: ignore[arg-type]
        if err != None:
            return (None, err)

        return (PacstallConfig(repositories=repo_list, settings=settingsConfig), None)  # type: ignore[arg-type]
    except Exception as error:
        fancy(
            "error",
            f"Unknown exception occurred while parsing config file.\n{error.args}",
        )
        return (None, ErrorCodes.SOFTWARE_ERROR)
