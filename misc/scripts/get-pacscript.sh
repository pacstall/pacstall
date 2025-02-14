#!/bin/bash

#     ____                  __        ____
#    / __ \____ ___________/ /_____ _/ / /
#   / /_/ / __ `/ ___/ ___/ __/ __ `/ / /
#  / ____/ /_/ / /__(__  ) /_/ /_/ / / /
# /_/    \__,_/\___/____/\__/\__,_/_/_/
#
# Copyright (C) 2020-present
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

# This script downloads pacscripts from the interwebs

{ ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }

function get_broken_package() {
    { ignore_stack=false; set -o pipefail; trap stacktrace ERR RETURN; }
    local pkg="${1}" broken_iter broken broken_pkg broken_desc broken_time
    local elapsed_seconds days hours minutes seconds
    broken="$(curl -s -- "${REPO}/broken-packages")"
    if [[ $? == 1 ]]; then
        return 0
    fi
    while IFS= read -r broken_iter; do
        broken_pkg="${broken_iter%% @*}"
        if [[ ${broken_pkg} == "${pkg}" ]]; then
            broken_desc="${broken_iter##*| }"
            broken_time="${broken_iter##* @}"
            broken_time="${broken_time%% |*}"

            elapsed_seconds=$(($(date +%s) - broken_time))

            days=$((elapsed_seconds / 86400))
            hours=$(( (elapsed_seconds % 86400) / 3600 ))
            minutes=$(( (elapsed_seconds % 3600) / 60 ))
            seconds=$((elapsed_seconds % 60))

            fancy_message warn $"'%s' has been marked as broken" "$PACKAGE"
            printf $"> %s days, %s hours, %s minutes, %s seconds ago\n" "$days" "$hours" "$minutes" "$seconds"
            printf $"Reason: %s\n" "$broken_desc"
            ask "Are you sure you want to install" N
            return $((answer == 0 ? 1 : 0))
        fi
    done < "${broken}"
}

if check_url "${URL}"; then
    if [[ $type == "install" ]]; then
        mkdir -p "$PACDIR" || {
            if ! [[ -w $PACDIR ]]; then
                suggested_solution $"Run '%b'" "${UCyan}sudo chown -R $PACSTALL_USER:$PACSTALL_USER $PACDIR${NC}"
            fi
        }
        if ! cd "$PACDIR"; then
            error_log 1 "install $PACKAGE"
            fancy_message error $"Could not enter %s" "$PACDIR"
            exit 1
        fi
    fi

    case "$URL" in
        *.pacscript | *packagelist | *.SRCINFO)
            FILE="${URL##*/}"
            [[ ${FILE} == ".SRCINFO" ]] && FILE="${PACKAGE}.SRCINFO"
            if ! get_broken_package "${PACKAGE}"; then
                exit 1
            fi
            if ! curl --location -s -- "$URL" > "$FILE"; then
                error_log 1 "download $PACKAGE"
                fancy_message error $"Could not download %s" "$URL"
                exit 1
            fi
            unset FILE
            ;;
        *)
            if ! download -- "$URL" > /dev/null 2>&1; then
                error_log 1 "download $PACKAGE"
                fancy_message error $"Could not download %s" "$URL"
                exit 1
            fi
            ;;
    esac
    return 0
else
    error_log 1 "get $PACKAGE pacscript"
    # shellcheck disable=SC2034
    { ignore_stack=true; return 1; }
fi
# vim:set ft=sh ts=4 sw=4 et:
