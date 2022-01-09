#!/bin/env python3

"""Repository commands."""

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

from typing import List, Tuple
from requests import exceptions, get
import subprocess
from api import config

from api.message import ask, ask_custom_question, fancy


def prompt_continue(
    repo_urls: List[str], add: bool = False, remove: bool = False
) -> bool:
    """
    Prints summary and prompts the user.

    Parameters
    ----------
    repo_urls:  List of repository urls to print
    add:        `True` if used for prompting repository insert
    remove:     `True` if used for prompting repository remove

    Returns
    -------
    `True` if user chose to continue and `False` otherwise
    """

    assert add != remove  # Panic if invocation is invalid

    used_for: str = "added" if add else ("removed" if remove else None)

    fancy("info", f"The following repositories are going to be {used_for}")
    fancy("info", repo_urls.join("\n"))

    reply = ask("info", "Are you sure you want to proceed?", "Y")
    return "yY".find(reply) != -1


def remove_many(repo_urls: List[str]) -> int:
    """
    Removes the given repository urls from the `pacstallrepos.txt` file.

    If at least one repository removal fails, the flow is stopped and a rollback is performed.

    Parameters
    ----------
    repo_urls: The repository urls to be removed.

    Return codes
    -----------
    0: Everything went fine.
    1: File not found or umet permissions.
    2: Repository not found in the repo list.
    3: Unknown error.
    """

    if not prompt_continue(repo_urls, remove=True):
        return 0

    for repo_url in repo_urls:
        code = remove(repo_url)

        if code != 0:
            fancy("error", f"Failed to remove repository '{repo_url}'. Rolling back..")

            for removed_repo_url in repo_urls[: repo_urls.index(repo_url)]:
                add_code = add(removed_repo_url)

                if add_code != 0:
                    fancy(
                        "error",
                        f"Rollback: Failed to add repository '{repo_url}'. Skipping..",
                    )
            return code


def remove(repo_url: str) -> int:
    """
    Removes the given repository url to the `pacstallrepos.txt` file

    Parameters
    ----------
    repo_url: The repository url to be added.

    Return codes
    -----------
    0: Everything went fine.
    1: File not found or umet permissions.
    2: Repository not found in the repo list.
    3: Unknown error.
    """

    CODE_OK = 0
    CODE_NOT_FOUND = 1
    CODE_ERR_NO_FILE_OR_INVALID_PERM = 2
    CODE_ERR_UNKNOWN = 3

    try:
        with open(config.PACSTALL_REPO_PATH, "w+") as file:
            content = file.read()
            existing_repos = content.splitlines()

            if repo_url not in existing_repos:
                # Write contents back as file got truncated
                file.write(content)
                return CODE_NOT_FOUND

            updated_repos = list(
                filter(lambda existing_repo: existing_repo != repo_url, existing_repos)
            )
            file.writelines(updated_repos)

        return CODE_OK
    except OSError:
        return CODE_ERR_NO_FILE_OR_INVALID_PERM
    except Exception:
        return CODE_ERR_UNKNOWN


def add_many(repo_urls: List[str]) -> int:
    """
    Adds the given repository urls to the `pacstallrepos.txt` file.

    If at least one repository insertion fails, the flow is stopped and a rollback is performed.

    Parameters
    ----------
    repo_urls:      The repository urls to be added.
    disable_prompt: Whether to or not to disable prompt.

    Return codes
    -----------
    0: Everything went fine.
    1: Connection problems.
    2: File not found or umet permissions.
    3: Conflict. Repository already added.
    4: Invalid repository URL
    5: Unknown error.
    """

    if not prompt_continue(repo_urls, add=True):
        return 0

    for repo_url in repo_urls:
        code = add(repo_url)

        if code != 0:
            fancy("error", f"Failed to add repository '{repo_url}'. Rolling back..")

            for added_repo_url in repo_urls[: repo_urls.index(repo_url)]:
                rm_code = remove(added_repo_url, skip_prompt=True)

                if rm_code != 0:
                    fancy(
                        "error",
                        f"Rollback: Failed to remove repository '{repo_url}'. Skipping..",
                    )
            return code


def choose_master_or_main(url_without_branch: str) -> str:
    """
    Returns the default repository branch. Possible values: `"master"`, `"main"` if successful, otherwise `None`.

    Parameters
    ----------
    url_without_branch: URL to the root of the repository, without the branch name. Example: `https://raw.githubusercontent.com/john-doe/pacstall-programs-fork`.
    """
    for branch in ["master", "main"]:
        try:
            # Choose branch by checking if the `packagelist` file exists
            with get(f"{url_without_branch}/{branch}/packagelist") as result:
                result.raise_for_status()
                return branch
        except Exception:
            pass

    return None


def parse_github_url(url: str) -> str:
    """
    Parses GitHub url and returns a url to the root of the files.

    Returns
    -------
    Url to the root of the files or `None` if error.
    """

    MAX_URL_PARTS_REQUIRED = 4
    [account, repository, tree, branch, *_] = url.split("github.com/")[1].split(
        "/"
    ) + MAX_URL_PARTS_REQUIRED * [None]

    if account == None or repository == None:
        return None

    raw_url_no_branch = f"https://raw.githubusercontent.com/{account}/{repository}"

    used_branch: str = None
    if tree == "tree" and branch != None:
        used_branch = branch
    else:
        used_branch = choose_master_or_main(raw_url_no_branch)

    if used_branch == None:
        return None

    return f"https://raw.githubusercontent.com/{account}/{repository}/{used_branch}"


def parse_gitlab_url(url: str) -> str:
    """
    Parses GitLab url and returns a url to the root of the files.

    Returns
    -------
    Url to the root of the files or `None` if error.
    """

    # If URL contains `/-/tree/` and there's only one word after that
    branch_from_url: List[str] = url.split("/-/tree/")[-1].split("/")
    if url.find("/-/tree/") and len(branch_from_url) == 1:
        return url.replace("/tree/", "/raw/")  # URL is well formatted

    MAX_URL_PARTS_REQUIRED = 2
    [account, repository, *_] = url.split("gitlab.com/")[1].split(
        "/"
    ) + MAX_URL_PARTS_REQUIRED * [None]

    if account == None or repository == None:
        return None

    used_branch = choose_master_or_main(
        f"https://gitlab.com/{account}/{repository}/-/raw"
    )

    if used_branch == None:
        return None

    return f"https://raw.githubusercontent.com/{account}/{repository}/{used_branch}"


def parse_bitbucket_url(url: str) -> str:
    """
    Parses Bitbucket url and returns a url to the root of the files.

    Returns
    -------
    Url to the root of the files or `None` if error.
    """

    # If URL contains `/-/tree/` and there's only one word after that
    branch_name_and_possibly_extra_slash = url.split("/src/")[-1].split("/")
    if url.find("/src/") and (
        len(branch_name_and_possibly_extra_slash) == 1
        or (
            len(branch_name_and_possibly_extra_slash) == 2
            and branch_name_and_possibly_extra_slash[1] == ""
        )
    ):
        return url.replace("/src/", "/raw/")  # URL is well formatted

    # URL does not contain the branch name
    MAX_URL_PARTS_REQUIRED = 2
    [account, repository, *_] = url.split("bitbucket.org/")[1].split(
        "/"
    ) + MAX_URL_PARTS_REQUIRED * [None]

    if account == None or repository == None:
        return None

    used_branch = choose_master_or_main(
        f"https://bitbucket.org/{account}/{repository}/raw"
    )

    if used_branch == None:
        return None

    return f"https://bitbucket.org/{account}/{repository}/raw/{used_branch}"


def add(repo_url: str) -> int:
    """
    Adds the given repository url to the `pacstallrepos.txt` file

    Parameters
    ----------
    repo_url (str): The repository url to be added.

    Return codes
    -----------
    0: Everything went fine.
    1: Connection problems.
    2: File not found or umet permissions.
    3: Conflict. Repository already added.
    4: Invalid repository URL
    5: Unknown error.
    """

    REQUEST_ERROR_MESSAGES = {
        exceptions.HTTPError: "A HTTP error occurred while connecting to the URL",
        exceptions.ConnectionError: "No internet connection detected",
        exceptions.Timeout: "Connection timed out. Check your internet connection",
        exceptions.TooManyRedirects: "Too many redirections. Possibly bad URL",
    }

    CODE_OK = 0
    CODE_ERR_CONN = 1
    CODE_ERR_NO_FILE_OR_INVALID_PERM = 2
    CODE_ERR_CONFLICT = 3
    CODE_ERR_INVALID_URL = 4
    CODE_ERR_UNKNOWN = 5

    try:
        if repo_url.find("github.com") != -1:
            repo_url = parse_github_url(repo_url)
        elif repo_url.find("gitlab.com") != -1:
            repo_url = parse_gitlab_url(repo_url)
        elif repo_url.find("bitbucket.org") != -1:
            repo_url = parse_bitbucket_url(repo_url)

        if repo_url == None:
            fancy(
                "error",
                "This repository does not exist or has an invalid file structure.",
            )
            return CODE_ERR_INVALID_URL

        packagelist_url = f"{repo_url}/packagelist"
        with get(packagelist_url) as result:
            result.raise_for_status()

            try:
                with open(config.PACSTALL_REPO_PATH, "r+") as file:
                    existing_repos = file.readlines()
                    if repo_url in existing_repos:
                        return CODE_ERR_CONFLICT

                    file.write(f"\n{repo_url}")
            except OSError:
                fancy(
                    "error",
                    f"Could not write repository to '{config.PACSTALL_REPO_PATH}'",
                )
                return CODE_ERR_NO_FILE_OR_INVALID_PERM
            return CODE_OK

    except (
        exceptions.HTTPError,
        exceptions.ConnectionError,
        exceptions.Timeout,
        exceptions.TooManyRedirects,
    ) as error:
        fancy("error", REQUEST_ERROR_MESSAGES[type(error)])
        return CODE_ERR_CONN

    except Exception as e:
        fancy("error", f"Unknown exception occurred.\n{e}")
        return CODE_ERR_UNKNOWN


def list_repos() -> int:
    """
    Prints the existing repositories.

    Return Codes
    -------
    0: Everything went fine.
    1: File not found or umet permissions.
    """
    CODE_OK = 0
    CODE_ERR_NO_FILE_OR_INVALID_PERM = 1

    try:
        with open(config.PACSTALL_REPO_PATH, "r") as file:
            existing_repos = file.readlines()
            for repo in existing_repos:
                fancy("log", f"\t-> {repo}")
    except OSError:
        fancy(
            "error",
            f"Could not read repository list from file '{config.PACSTALL_REPO_PATH}'",
        )
        return CODE_ERR_NO_FILE_OR_INVALID_PERM
    return CODE_OK
