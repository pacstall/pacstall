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

function cleanup() {
    if [[ -n $KEEP ]]; then
        sudo rm -rf "/tmp/pacstall-keep/$name"
        mkdir -p "/tmp/pacstall-keep/$name"
        if [[ -f /tmp/pacstall-pacdeps-"$PACKAGE" ]]; then
            sudo mv /tmp/pacstall-pacdep/* "/tmp/pacstall-keep/$name"
        else
            sudo mv /tmp/pacstall/* "/tmp/pacstall-keep/$name"
        fi
    fi
    if [[ -f /tmp/pacstall-pacdeps-"$PACKAGE" ]]; then
        rm -rf /tmp/pacstall-pacdeps-"$PACKAGE"
        sudo rm -rf /tmp/pacstall-pacdep
    else
        sudo rm -rf "${SRCDIR:?}"/*
        # just in case we quit before $name is declared, we should be able to remove a fake directory so it doesn't exit out the script
        sudo rm -rf "${STOWDIR:-/usr/src/pacstall}/${name:-raaaaaaaandom}"
        sudo rm -rf /tmp/pacstall/*
        sudo rm -rf /tmp/pacstall-gives
    fi
    sudo rm -rf "${STOWDIR}/${name:-$PACKAGE}.deb"
    rm -f /tmp/pacstall-select-options
    unset name version url build_depends depends breaks replace description hash optdepends ppa maintainer pacdeps patch PACPATCH NOBUILDDEP optinstall gives pac_functions 2> /dev/null
    unset -f pkgver removescript prepare build install 2> /dev/null
}

function trap_ctrlc() {
    echo ""
    fancy_message warn "Interrupted, cleaning up"
    if dpkg-query -W -f='${Status}' "$name" 2> /dev/null | grep -q -E "ok installed|ok unpacked"; then
        sudo apt-get purge "$name" -y > /dev/null
    fi
    sudo rm -f /etc/apt/preferences.d/"${name:-$PACKAGE}-pin"
    cleanup
    exit 1
}

# run checks to verify script works
function checks() {
    if [[ -z $name ]]; then
        fancy_message error "Package does not contain name"
        exit 1
    fi
    if [[ -z $hash && $name != *-git ]]; then
        fancy_message warn "Package does not contain a hash"
    fi
    if [[ -z $version ]]; then
        fancy_message error "Package does not contain version"
        exit 1
    fi
    if [[ -z $url ]]; then
        fancy_message error "Package does not contain URL"
        exit 1
    fi
    if [[ -z $maintainer ]]; then
        fancy_message warn "Package does not have a maintainer. Please be advised"
    fi
}

function cget() {
    URL="$1"
    BRANCH="$2"
    # If BRANCH was not specified, default to master
    if [[ -n $BRANCH ]]; then
        BRANCH=master
    fi
    git ls-remote "$URL" "$BRANCH" | sed "s/refs\/heads\/.*//"
}

# Logging metadata
function log() {

    # Origin repo info parsing
    if [[ $local == 'no' ]]; then
        if echo "$REPO" | grep "github" > /dev/null; then
            pURL="${REPO/'raw.githubusercontent.com'/'github.com'}"
            pURL="${pURL%/*}"
            pBRANCH="${REPO##*/}"
            branch="yes"
        elif echo "$REPO" | grep "gitlab" > /dev/null; then
            pURL="${REPO%/-/raw/*}"
            pBRANCH="${REPO##*/-/raw/}"
            branch="yes"
        else
            pURL=$REPO
            branch="no"
        fi
    fi

    # Metadata writing
    {
        echo "_name=\"$name"\"
        if [[ -n $pkgname ]]; then
            echo "_pkgname=\"$pkgname"\"
        fi
        echo "_version=\"$version"\"
        echo "_date=\"$(date)"\"
        if [[ -n $ppa ]]; then
            echo "_ppa=\"$ppa"\"
        fi
        if [[ -n $gives ]]; then
            echo "_gives=\"$gives"\"
        fi
        if [[ -f /tmp/pacstall-pacdeps-"$name" ]]; then
            echo '_pacstall_depends="true"'
        fi
        if [[ $local == 'no' ]]; then
            echo "_remoterepo=\"$pURL"\"
            if [[ $branch == 'yes' ]]; then
                echo "_remotebranch=\"$pBRANCH"\"
            fi
        fi
        if [[ -n ${pacdeps[*]} ]]; then
            echo "_pacdeps=(${pacdeps[*]})"
        fi
    } | sudo tee "$LOGDIR/$name" > /dev/null
}

function compare_remote_version() (
    local input="${1}"
    source "$LOGDIR/$input" || return 1
    if [[ -z ${_remoterepo} ]]; then
        return
    elif echo "${_remoterepo}" | grep "github.com" > /dev/null; then
        local remoterepo="${_remoterepo/'github.com'/'raw.githubusercontent.com'}/${_remotebranch}"
    elif echo "${_remoterepo}" | grep "gitlab.com" > /dev/null; then
        local remoterepo="${_remoterepo}/-/raw/${_remotebranch}"
    else
        local remoterepo="${_remoterepo}"
    fi
    local remotever="$(source <(curl -s -- "$remoterepo"/packages/"$input"/"$input".pacscript) && type pkgver &> /dev/null && pkgver || echo "$version")" > /dev/null
    if [[ $input == *"-git" ]]; then
        if [[ $(pacstall -V $input) != "$remotever" ]]; then
            echo "update"
        else
            echo "no"
        fi
    elif dpkg --compare-versions "$(pacstall -V $input)" lt "$remotever" > /dev/null 2>&1; then
        echo "update"
    else
        echo "no"
    fi
)

function deblog() {
    local key="$1"
    local content="$2"
    echo "$key: $content" | sudo tee -a "$STOWDIR/$name/DEBIAN/control" > /dev/null
}

function clean_builddir() {
    sudo rm -rf "${STOWDIR}/${name:?}"
    sudo rm -f "${STOWDIR}/${name}.deb"
}

function prompt_optdepends() {
    if [[ -n $depends ]]; then
        deps=($depends)
    fi
    if [[ ${#optdepends[@]} -ne 0 ]]; then
        for i in "${optdepends[@]}"; do
            if ! grep -q ':' <<< "${i}"; then
                fancy_message error "${i} does not have a description"
                cleanup
                return 1
            fi
        done

        local optdeps=()
        for optdep in "${optdepends[@]}"; do
            local opt=${optdep%%: *}
            # Check if package exists in the repos, and if not, go to the next program
            if [[ -z "$(apt-cache search --names-only "^$opt\$")" ]]; then
                missing_optdeps+=("${opt}")
                continue
            fi
            # Add to the dependency list if already installed so it doesn't get autoremoved on upgrade
            # If the package is not installed already, add it to the list. It's much easier for a user to choose from a list of uninstalled packages than every single one regardless of it's status
            if ! dpkg-query -W -f='${Status}' "${opt}" 2> /dev/null | grep "^install ok installed" > /dev/null 2>&1; then
                optdeps+=("${optdep}")
            else
                deps+=("${opt}")
            fi
        done

        if [[ ${#optdeps[@]} -ne 0 ]]; then
            fancy_message sub "Optional dependencies"
            if [[ -n ${missing_optdeps[*]} ]]; then
                for i in "${missing_optdeps[@]}"; do
                    echo -ne "\t"
                    fancy_message warn "${BLUE}$i${NC} does not exist in apt repositories"
                done
            fi
            z=1
            for i in "${optdeps[@]}"; do
                # print optdepends with bold package name
                echo -e "\t\t[${BICyan}$z${NC}] ${BOLD}${i%%:*}${NC}:${i#*:}"
                ((z++))
            done
            unset z
            # tab over the next line
            echo -ne "\t"
            select_options "Select optional dependencies to install" "${#optdeps[@]}"
            choices=($(cat /tmp/pacstall-select-options))
            if [[ ${choices[0]} != "n" ]]; then
                for i in "${choices[@]}"; do
                    ((i--))
                    local s="${optdeps[$i]}"
                    # does `s` actually exist in the optdeps array?
                    if [[ -n $s ]]; then
                        # then add it, and strip the `:`
                        deps+=("${s%%: *}")
                        local not_installed_yet_optdeps+=("${s%%: *}")
                    fi
                done
                if [[ -n ${deps[*]} ]]; then
                    fancy_message info "Selecting packages ${BCyan}${not_installed_yet_optdeps[*]}${NC}"
                fi
                if pacstall -L | grep -E "(^| )${name}( |$)" > /dev/null 2>&1; then
                    sudo dpkg -r --force-all "$name" > /dev/null
                fi
            else
                # Add to the suggests anyway. They won't get installed but can be queried
                deblog "Suggests" "$(echo "${optdeps[@]}" | awk -F': ' '{print $1}' | tr '\n' ',' | head -c -1)"
            fi
        fi
    fi

    if [[ -n ${deps[*]} ]]; then
        if [[ -n ${pacdeps[*]} ]]; then
            for i in "${pacdeps[@]}"; do
                (   
                    source "$LOGDIR/$i"
                    if [[ -n $_gives ]]; then
                        echo "$_gives" | tee -a /tmp/pacstall-gives > /dev/null
                    else
                        echo "$_name" | tee -a /tmp/pacstall-gives > /dev/null
                    fi
                )
            done
            deps+=($(cat /tmp/pacstall-gives))
        fi
    fi
    if [[ -n $depends ]] || [[ -n ${deps[*]}  ]]; then
        deblog "Depends" "$(echo "${deps[@]}" | sed 's/ /, /g')"
    fi
}

function generate_changelog() {
    echo -e "${name} ($version) $(lsb_release -sc); urgency=medium\n"
    echo -e "  * Version now at $version.\n"
    echo -e " -- $maintainer  $(date +"%a, %d %b %Y %T %z")"
}

function createdeb() {
    local name="$1"
    if [[ $PACSTALL_INSTALL == "0" ]]; then
        # We are not going to immediately install, meaning the user might want to share their deb with someone else, so create the highest compression. We want maximum compression over everything else
        local gzip_flags="-9n"
    else
        # Immediate install, so we want fast build times over everything else
        local gzip_flags="-1n"
    fi
    cd "$STOWDIR/$name"
    echo "2.0" | sudo tee debian-binary > /dev/null
    sudo tar -cf "$PWD/control.tar" -T /dev/null
    local CONTROL_LOCATION="$PWD/control.tar"
    # avoid having to cd back
    (   
        # create control.tar
        cd DEBIAN
        for i in *; do
            if [[ -f $i ]]; then
                local files_for_control+=("$i")
            fi
        done
        fancy_message sub "Packing control.tar"
        sudo tar -rf "$CONTROL_LOCATION" "${files_for_control[@]}"
    )
    sudo tar -cf "$PWD/data.tar" -T /dev/null
    local DATA_LOCATION="$PWD/data.tar"
    # collect every top level dir except for DEBIAN
    for i in *; do
        if [[ -d $i ]] && [[ $i != "DEBIAN" ]]; then
            local files_for_data+=("$i")
        fi
    done
    fancy_message sub "Packing data.tar"
    sudo tar -rf "$DATA_LOCATION" "${files_for_data[@]}"

    fancy_message sub "Compressing"
    sudo gzip "$gzip_flags" "$DATA_LOCATION" "$CONTROL_LOCATION"
    sudo ar -rU "$name.deb" debian-binary control.tar.gz data.tar.gz > /dev/null 2>&1
    sudo mv "$name.deb" ..
    sudo rm -f debian-binary control.tar.gz data.tar.gz
}

function makedeb() {
    fancy_message info "Packaging $name"
    deblog "Package" "$name"

    if [[ $version =~ ^[0-9] ]]; then
        deblog "Version" "${version}"
        export version="${version}"
    else
        deblog "Version" "0${version}"
        export version="0${version}"
    fi

    deblog "Architecture" "all"
    deblog "Section" "Pacstall"
    deblog "Priority" "optional"

    if [[ -n $replace ]]; then
        deblog "Conflicts" "${replace//' '/', '}"
        deblog "Replace" "${replace//' '/', '}"
    fi

    if echo "$gives" | grep -q ",\|\\s"; then
        local comma_gives="${gives// /, }"
    else
        local comma_gives="${gives:-$name}"
    fi

    deblog "Provides" "${comma_gives}"
    deblog "Maintainer" "${maintainer:-Pacstall <pacstall@pm.me>}"
    deblog "Description" "${description}"

    for i in {removescript,postinst}; do
        case $i in
            removescript) export deb_post_file="postrm" ;;
            postinst) export deb_post_file="postinst" ;;
        esac
        if [[ $(type -t $i) == function ]]; then
            echo '#!/bin/bash
set -e
function ask() {
	local default reply
	if [[ ${2:-} = "Y" ]]; then
		echo -ne "$1 [Y/n] "
		default="Y"
	elif [[ ${2:-} = "N" ]]; then
		echo -ne "$1 [y/N] "
	fi
	default=${2:-}
	read -r reply <&0
	if [[ -z $reply ]]; then
		reply=$default
	fi
	case "$reply" in
		Y*|y*) export answer=1; return 0;;
		N*|n*) export answer=0; return 1;;
	esac
}
function fancy_message() {
	local MESSAGE_TYPE="${1}"
	local MESSAGE="${2}"
	local BOLD=$(tput bold)
	local NC="\033[0m"
	case ${MESSAGE_TYPE} in
		info) echo -e "[${BOLD}+${NC}] INFO: ${MESSAGE}";;
		warn) echo -e "[${BOLD}*${NC}] WARNING: ${MESSAGE}";;
		error) echo -e "[${BOLD}!${NC}] ERROR: ${MESSAGE}";;
		sub) echo -e "\t[${BOLD}>${NC}] ${MESSAGE}" ;;
		*) echo -e "[${BOLD}?${NORMAL}] UNKNOWN: ${MESSAGE}";;
	esac
}

hash -r' | sudo tee "$STOWDIR/$name/DEBIAN/$deb_post_file" > /dev/null
            {
                echo -e "export name=\"${name}\""
                if [[ -n ${pkgname} ]]; then
                    echo -e "export pkgname=\"${pkgname}\""
                fi
                echo -e "export pkgdir=\"${pkgdir}\""
                if [[ -n ${gives} ]]; then
                    echo -e "export gives=\"${gives}\""
                fi
                echo -e "export version=\"${version}\""
                echo -e "export maintainer=\"${maintainer:-Pacstall <pacstall@pm.me>}\""
                echo -e "$(declare -f "$i")\n$i"
            } | sudo tee -a "$STOWDIR/$name/DEBIAN/$deb_post_file" > /dev/null
        fi
    done
    echo -e "sudo rm -f $LOGDIR/$name\nsudo rm -f /etc/apt/preferences.d/$name.pin" | sudo tee -a "$STOWDIR/$name/DEBIAN/postrm" > /dev/null
    for i in {postrm,postinst}; do
        sudo chmod -x "$STOWDIR/$name/DEBIAN/$i" 1> /dev/null 2>&1
        sudo chmod 755 "$STOWDIR/$name/DEBIAN/$i" 1> /dev/null 2>&1
    done

    deblog "Installed-Size" "$(sudo du -s --apparent-size --exclude=DEBIAN -- "$STOWDIR/$name" | awk '{print $1}')"

    generate_changelog | sudo tee -a "$STOWDIR/$name/DEBIAN/changelog" > /dev/null

    cd "$STOWDIR"
    if ! createdeb "$name"; then
        fancy_message error "Could not create package"
        error_log 5 "install $PACKAGE"
        fancy_message info "Cleaning up"
        cleanup
        return 1
    fi

    if [[ $PACSTALL_INSTALL != 0 ]]; then

        # --allow-downgrades is to allow git packages to "downgrade", because the commits aren't necessarily a higher number than the last version
        if ! sudo --preserve-env=PACSTALL_INSTALL apt-get install --reinstall "$STOWDIR/$name.deb" -y --allow-downgrades 2> /dev/null; then
            echo -ne "\t"
            fancy_message error "Failed to install $name deb"
            error_log 8 "install $PACKAGE"
            sudo dpkg -r --force-all "$name" > /dev/null
            fancy_message info "Cleaning up"
            cleanup
            exit 1
        fi

        sudo rm -rf "$STOWDIR/$name"
        sudo rm -rf "$SRCDIR/$name.deb"

        if ! [[ -d /etc/apt/preferences.d/ ]]; then
            sudo mkdir -p /etc/apt/preferences.d
        fi
        echo "Package: ${name}
Pin: version *
Pin-Priority: -1" | sudo tee /etc/apt/preferences.d/"${name}-pin" > /dev/null
        return 0
    else
        sudo mv "$STOWDIR/$name.deb" "$PACDEB_DIR"
        sudo chown "$PACSTALL_USER":"$PACSTALL_USER" "$PACDEB_DIR/$name.deb"
        fancy_message info "Package built at ${BGreen}$PACDEB_DIR/$name.deb${NC}"
        fancy_message info "Moving ${BGreen}$STOWDIR/$name${NC} to ${BGreen}/tmp/pacstall-no-build/$name${NC}"
        sudo rm -rf "/tmp/pacstall-no-build/$name"
        sudo mkdir -p "/tmp/pacstall-no-build/$name"
        sudo mv "$STOWDIR/$name" "/tmp/pacstall-no-build/$name"
        cleanup
        exit 0
    fi
}

ask "Do you want to view/edit the pacscript" N
if [[ $answer -eq 1 ]]; then
    if [[ -n $PACSTALL_EDITOR ]]; then
        $PACSTALL_EDITOR "$PACKAGE".pacscript
    elif [[ -n $EDITOR ]]; then
        $EDITOR "$PACKAGE".pacscript
    elif [[ -n $VISUAL ]]; then
        $VISUAL "$PACKAGE".pacscript
    else
        sensible-editor "$PACKAGE".pacscript
    fi
fi

fancy_message info "Sourcing pacscript"
DIR=$(pwd)
homedir="/home/$PACSTALL_USER"
export homedir

pacfile=$(readlink -f "$PACKAGE".pacscript)
export pacfile
if ! source "$PACKAGE".pacscript; then
    fancy_message error "Could not source pacscript"
    error_log 12 "install $PACKAGE"
    fancy_message info "Cleaning up"
    cleanup
    return 1
fi

clean_builddir
sudo mkdir -p "$STOWDIR/$name/DEBIAN"

if type pkgver > /dev/null 2>&1; then
    version=$(pkgver) > /dev/null
fi

# Run checks function
if ! checks; then
    fancy_message error "There was an error checking the script!"
    error_log 6 "install $PACKAGE"
    fancy_message info "Cleaning up"
    cleanup
    return 1
fi

# Trap Crtl+C just before the point cleanup is first needed
trap "trap_ctrlc" 2

if [[ -n $ppa ]]; then
    for i in "${ppa[@]}"; do
        # Add ppa, but ppa bad I guess
        sudo add-apt-repository ppa:"$i"
    done
fi

if [[ -n $pacdeps ]]; then
    for i in "${pacdeps[@]}"; do
        # If /tmp/pacstall-pacdeps-"$i" is available, it will trigger the logger to log it as a dependency
        touch /tmp/pacstall-pacdeps-"$i"

        [[ $KEEP ]] && cmd="-KPI" || cmd="-PI"
        if pacstall -L | grep -E "(^| )${i}( |$)" > /dev/null 2>&1; then
            pacstall_pacdep_status="$(compare_remote_version $i)"
            if [[ -z $UPGRADE ]] && [[ $pacstall_pacdep_status == "update" ]]; then
                fancy_message info "Found newer version for $i pacdep"
                if ! pacstall "$cmd" "$i"; then
                    fancy_message error "Failed to install dependency"
                    error_log 8 "install $PACKAGE"
                    cleanup
                    return 1
                fi
            else
                fancy_message info "The pacstall dependency ${i} is already installed and at latest version"

            fi
        elif fancy_message info "Installing $i" && ! pacstall "$cmd" "$i"; then
            fancy_message error "Failed to install dependency"
            error_log 8 "install $PACKAGE"
            cleanup
            return 1
        fi
    done
fi

if ! pacstall -L | grep -E "(^| )${name}( |$)" > /dev/null 2>&1; then
    if [[ -n $breaks ]]; then
        for pkg in $breaks; do
            if dpkg-query -W -f='${Status} ${Section}' "${pkg}" 2> /dev/null | grep "^install ok installed" | grep -v "Pacstall" > /dev/null 2>&1; then
                # Check if anything in breaks variable is installed already
                fancy_message error "${RED}$name${NC} breaks $pkg, which is currently installed by apt"
                error_log 13 "install $PACKAGE"
                fancy_message info "Cleaning up"
                cleanup
                return 1
            fi
            if [[ ${pkg} != "${name}" ]] && pacstall -L | grep -E "(^| )${pkg}( |$)" > /dev/null 2>&1; then
                # Same thing, but check if anything is installed with pacstall
                fancy_message error "${RED}$name${NC} breaks $pkg, which is currently installed by pacstall"
                error_log 13 "install $PACKAGE"
                fancy_message info "Cleaning up"
                cleanup
                return 1
            fi
        done
    fi

    if [[ -n $replace ]]; then
        # Ask user if they want to replace the program
        if dpkg-query -W -f='${Status}' $replace 2> /dev/null | grep -q "ok installed"; then
            ask "This script replaces $replace. Do you want to proceed" N
            if [[ $answer -eq 0 ]]; then
                fancy_message info "Cleaning up"
                cleanup
                return 1
            fi
            sudo apt-get remove -y $replace
        fi
    fi
fi

if [[ -n ${build_depends[*]} ]]; then
    # Get all uninstalled build depends
    build_depends=($build_depends)
    for build_dep in "${build_depends[@]}"; do
        if dpkg-query -W -f='${Status}' "${build_dep}" 2> /dev/null | grep "^install ok installed" > /dev/null 2>&1; then
            build_depends_to_delete+=("${build_dep}")
        fi
    done

    for target in "${build_depends_to_delete[@]}"; do
        for i in "${!build_depends[@]}"; do
            if [[ ${build_depends[i]} == "$target" ]]; then
                unset 'build_depends[i]'
            fi
        done
    done

    fancy_message info "${BLUE}$name${NC} requires ${CYAN}$(echo -e "${build_depends[*]}")${NC} to install"
    ask "Do you want to remove them after installing ${BLUE}$name${NC}" N
    if [[ $answer -eq 0 ]]; then
        NOBUILDDEP=0
    else
        NOBUILDDEP=1
    fi

    if ! sudo apt-get install -y -qq -o=Dpkg::Use-Pty=0 ${build_depends[*]}; then
        fancy_message error "Failed to install build dependencies"
        error_log 8 "install $PACKAGE"
        fancy_message info "Cleaning up"
        cleanup
        return 1
    fi
fi

function hashcheck() {
    inputHash=$hash
    # Get hash of file
    fileHash="$(sha256sum "$1" | sed 's/\s.*$//')"

    # Check if the input hash is the same as of the downloaded file.
    # Skip this test if the hash variable doesn't exist in the pacscript.
    if [[ $inputHash != "$fileHash" ]] && [[ -n ${hash} ]]; then
        # We bad
        fancy_message error "Hashes don't match"
        error_log 16 "install $PACKAGE"
        if [[ $url != *".deb" ]]; then
            sudo dpkg -r "$name" > /dev/null
        fi

        fancy_message info "Cleaning up"
        cleanup
        return 1
    fi
    true
}

fancy_message info "Retrieving packages"
if [[ -f /tmp/pacstall-pacdeps-"$PACKAGE" ]]; then
    mkdir -p "/tmp/pacstall-pacdep"
    if ! cd "/tmp/pacstall-pacdep" 2> /dev/null; then
        error_log 1 "install $PACKAGE"
        fancy_message error "Could not enter ${SRCDIR}"
        exit 1
    fi
else
    mkdir -p "$SRCDIR"
    if ! cd "$SRCDIR" 2> /dev/null; then
        error_log 1 "install $PACKAGE"
        fancy_message error "Could not enter ${SRCDIR}"
        exit 1
    fi
fi

sudo mkdir -p "/tmp/pacstall"
sudo chown "$PACSTALL_USER" -R /tmp/pacstall

if [[ -n $patch ]]; then
    fancy_message info "Downloading patches"
    mkdir -p PACSTALL_patchesdir
    for i in "${patch[@]}"; do
        wget -q "$i" -P PACSTALL_patchesdir &
    done
    wait
    export PACPATCH=$(pwd)/PACSTALL_patchesdir
fi

if [[ $name == *-git ]]; then
    # git clone quietly, with no history, and if submodules are there, download with 10 jobs
    git clone --quiet --depth=1 --jobs=10 "$url"
    # cd into the directory
    cd ./*/ 2> /dev/null || {
        error_log 1 "install $PACKAGE"
        fancy_message warn "Could not enter into the cloned git repository"
        fancy_message info "Cleaning up"
        cleanup
        exit 1
    }
    # Check the integrity
    git fsck --full
else
    case "$url" in
        *.zip)
            if ! download "$url"; then
                error_log 1 "download $PACKAGE"
                fancy_message error "Failed to download package"
                fancy_message info "Cleaning up"
                cleanup
                exit 1
            fi
            # hash the file
            if ! hashcheck "${url##*/}"; then
                return 1
            fi
            # unzip file
            fancy_message info "Extracting ${url##*/}"
            unzip -qo "${url##*/}" 1>&1 2> /dev/null
            # cd into it
            cd ./*/ 2> /dev/null || {
                error_log 1 "install $PACKAGE"
                fancy_message warn "Could not enter into the downloaded archive"
            }
            ;;
        *.deb)
            if ! download "$url"; then
                error_log 1 "download $PACKAGE"
                fancy_message error "Failed to download package"
                fancy_message info "Cleaning up"
                cleanup
                exit 1
            fi
            if ! hashcheck "${url##*/}"; then
                return 1
            fi
            if sudo apt install -y -f ./"${url##*/}" 2> /dev/null; then
                log
                if type -t postinst > /dev/null 2>&1; then
                    if ! postinst; then
                        error_log 5 "postinst hook"
                        fancy_message error "Could not run postinst hook successfully"
                        exit 1
                    fi
                fi

                fancy_message info "Storing pacscript"
                sudo mkdir -p /var/cache/pacstall/"$PACKAGE"/"$version"
                if ! cd "$DIR" 2> /dev/null; then
                    error_log 1 "install $PACKAGE"
                    fancy_message error "Could not enter into ${DIR}"
                    exit 1
                fi
                sudo cp -r "$PACKAGE".pacscript /var/cache/pacstall/"$PACKAGE"/"$version"
                sudo chmod o+r /var/cache/pacstall/"$PACKAGE"/"$version"/"$PACKAGE".pacscript
                fancy_message info "Cleaning up"
                cleanup
                return 0

            else
                fancy_message error "Failed to install the package"
                error_log 14 "install $PACKAGE"
                sudo dpkg -r "$name" > /dev/null
                fancy_message info "Cleaning up"
                cleanup
                return 1
            fi
            ;;
        *.AppImage)
            if ! download "$url"; then
                error_log 1 "download $PACKAGE"
                fancy_message error "Failed to download package"
                fancy_message info "Cleaning up"
                cleanup
                exit 1
            fi
            if ! hashcheck "${url##*/}"; then
                return 1
            fi
            ;;
        *)
            if ! download "$url"; then
                error_log 1 "download $PACKAGE"
                fancy_message error "Failed to download package"
                fancy_message info "Cleaning up"
                cleanup
                exit 1
            fi
            # I think you get it by now
            if ! hashcheck "${url##*/}"; then
                return 1
            fi
            fancy_message info "Extracting ${url##*/}"
            tar -xf "${url##*/}" 1>&1 2> /dev/null
            cd ./*/ 2> /dev/null || {
                error_log 1 "install $PACKAGE"
                fancy_message warn "Could not enter into the downloaded archive"
            }
            ;;
    esac
fi

export srcdir="$PWD"
sudo chown -R "$PACSTALL_USER":"$PACSTALL_USER" . 2> /dev/null

export pkgdir="$STOWDIR/$name"
export -f ask fancy_message select_options

# Trap so that we can clean up (hopefully without messing up anything)
trap cleanup ERR
trap - SIGINT

prompt_optdepends

for i in {prepare,build,install}; do
    if [[ $(type -t "$i") == function ]]; then
        pac_functions+=("$i")
    fi
done
if [[ -n ${pac_functions[*]}   ]]; then
    fancy_message info "Running functions"
    for function in "${pac_functions[@]}"; do
        fancy_message sub "Running $function"
        bash -ceuo pipefail "source $pacfile
		$function" || {
            error_log 5 "$function $PACKAGE"
            echo -ne "\t"
            fancy_message error "Could not $function $PACKAGE properly"
            sudo dpkg -r "$name" > /dev/null
            fancy_message info "Cleaning up"
            cleanup
            exit 1
        }
    done
fi

trap - ERR

if [[ $NOBUILDDEP -eq 1 ]]; then
    fancy_message info "Purging build dependencies"
    # shellcheck disable=2086
    sudo apt-get purge --auto-remove -y ${build_depends[*]}
fi

cd "$HOME" 2> /dev/null || (
    error_log 1 "install $PACKAGE"
    fancy_message warn "Could not enter into ${HOME}"
)

makedeb

# Metadata writing
log

# `hash -r` updates PATH database
hash -r

fancy_message info "Performing post install operations"
fancy_message sub "Storing pacscript"
sudo mkdir -p /var/cache/pacstall/"$PACKAGE"/"$version"
if ! cd "$DIR" 2> /dev/null; then
    error_log 1 "install $PACKAGE"
    fancy_message error "Could not enter into ${DIR}"
    sudo dpkg -r "${gives:-$name}" > /dev/null
    fancy_message info "Cleaning up"
    cleanup
    exit 1
fi

sudo cp -r "$PACKAGE".pacscript /var/cache/pacstall/"$PACKAGE"/"$version"
sudo chmod o+r /var/cache/pacstall/"$PACKAGE"/"$version"/"$PACKAGE".pacscript

fancy_message sub "Cleaning up"
cleanup

return 0

# vim:set ft=sh ts=4 sw=4 noet:
