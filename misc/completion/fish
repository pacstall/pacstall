#!/usr/bin/env fish

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
alias _seen "__fish_seen_subcommand_from"

# Flag lists
set -l pacstall_cmds -I --install -S --search --remove -A --add-repo -U --update -V --version -L --list -Up --upgrade -Qi --query-info -D --download -T --tree -P --disable-prompts -K --keep -PI -PR -PUp -IP -RP -UpP -KI -KUp -IK -UpK -BI -IB -PK -KP -BK -KB -PB -BP -PKI -PKUp -KPI -KPUp -PIK -PUpK -KIP -KUpP -IPK -UpPK -IKP -UpKP -PBI -BPI -PIB -BIP -IPB -IBP -KBI -BKI -KIB -KIP -IPK -IKP -BPK -BKP -PBK -PKB -KBP -KPB -BPKI -BKPI -PBKI -PKBI -KBPI -KPBI -BPIK -BKIP -PBIK -PKIB -KBIP -KPIB -BIPK -BIKP -PIBK -PIKB -KIBP -KIPB -IBPK -IBKP -IPBK -IPKB -IKBP -IKPB

# Up cmds
set -l pacstall_up_cmds -Up -PUp -PKUp -KPUp -UpP -UpPK -UpKP

# R cmds
set -l pacstall_r_cmds -R -PR -RP

# P cmds
set -l pacstall_p -P --disable-prompts
set -l pacstall_p_cmds -I --install -R --remove -Up --upgrade
set -l pacstall_p_grouped -PI -PR -PUp -PK -PKI -PKUp -KP -KPI -KPUp -IP -RP -UpP -IPK -UpPK -IKP -UpKP -PB -BP -PBI -BPI -PIB -BIP -IPB -IBP -BPK -BKP -PBK -PKB -KBP -KPB -BPKI -BKPI -PBKI -PKBI -KBPI -KPBI -BPIK -BKIP -PBIK -PKIB -KBIP -KPIB -BIPK -BIKP -PIBK -PIKB -KIBP -KIPB -IBPK -IBKP -IPBK -IPKB -IKBP -IKPB

# K cmds
set -l pacstall_k -K --keep
set -l pacstall_k_cmds -I --install -Up --upgrade
set -l pacstall_k_grouped -KI -KUp -KP -KPI -KPUp -PK -PKI -PKUp -IK -UpK -IKP -UpKP -IPK -UpPK -BK -KB -BKI -KBI -BIK -KIB -IBK -IKB -BPK -BKP -PBK -PKB -KBP -KPB -BPKI -BKPI -PBKI -PKBI -KBPI -KPBI -BPIK -BKIP -PBIK -PKIB -KBIP -KPIB -BIPK -BIKP -PIBK -PIKB -KIBP -KIPB -IBPK -IBKP -IPBK -IPKB -IKBP -IKPB

# B cmds
set -l pacstall_b -B --build-only
set -l pacstall_b_cmds -I --install
set -l pacstall_b_grouped -BI -BP -BPI -PB -PBI -IB -IBP -IPB -BKI -BKP -BKPI -PKB -PKBI -KPIB -KIBP -IKPB

# Mixed cmds
set -l pacstall_bp -PB -BP
set -l pacstall_bk -BK -KB
set -l pacstall_pk -PK -KP
set -l pacstall_bkp -BPK -BKP -PBK -PKB -KBP -KPB

# Completion for normal commands
complete -f -c pacstall
complete -f -c pacstall -n "not _seen $pacstall_cmds" -o S -l search -d 'Search for package'
complete -f -c pacstall -n "not _seen $pacstall_cmds" -o A -l add-repo -d 'Add repository'
complete -f -c pacstall -n "not _seen $pacstall_cmds" -o U -l update -d 'Update pacstall scripts'
complete -f -c pacstall -n "not _seen $pacstall_cmds" -o V -l version -d 'Print pacstall version'
complete -f -c pacstall -n "not _seen $pacstall_cmds" -o L -l list -d 'List packages installed'
complete -f -c pacstall -n "not _seen $pacstall_cmds" -o D -l download -d 'Downloads package'
complete -f -c pacstall -n "not _seen $pacstall_cmds" -o T -l tree -d 'Makes a tree of a package'
complete -f -c pacstall -n "not _seen $pacstall_cmds" -o Qi -l query-info -d 'Get package info'

complete -f -c pacstall -n "not _seen $pacstall_cmds" -o I -l install -d 'Install package'
complete -f -c pacstall -n "not _seen $pacstall_cmds" -o R -l remove -d 'Remove package'
complete -f -c pacstall -n "not _seen $pacstall_cmds" -o Up -l upgrade -d 'Upgrade packages'

complete -f -c pacstall -n "_seen $pacstall_p_cmds $pacstall_b_grouped $pacstall_k_grouped && not _seen $pacstall_p $pacstall_pk $pacstall_bp $pacstall_bkp $pacstall_p_grouped" -o P -l disable-prompts -d 'Disable prompts'
complete -f -c pacstall -n "_seen $pacstall_k_cmds $pacstall_p_grouped $pacstall_b_grouped && not _seen $pacstall_k $pacstall_pk $pacstall_bk $pacstall_bkp $pacstall_k_grouped $pacstall_r_cmds" -o K -l keep -d 'Retain build dir'
complete -f -c pacstall -n "_seen $pacstall_b_cmds $pacstall_p_grouped $pacstall_k_grouped && not _seen $pacstall_b $pacstall_bk $pacstall_bp $pacstall_bkp $pacstall_b_grouped $pacstall_r_cmds $pacstall_up_cmds" -o B -l build-only -d 'Build package'

# Completions for P commands

complete -f -c pacstall -n "not _seen $pacstall_cmds" -o PR -d 'Disable and Remove'
complete -f -c pacstall -n "_seen $pacstall_p && not _seen $pacstall_p_cmds $pacstall_k $pacstall_pk $pacstall_p_grouped" -o R -l remove -d 'Remove package'

complete -f -c pacstall -n "not _seen $pacstall_cmds || _seen $pacstall_b $pacstall_k $pacstall_bk && not _seen $pacstall_p $pacstall_p_cmds $pacstall_p_grouped" -o PI -d 'Disable and Install'
complete -f -c pacstall -n "not _seen $pacstall_cmds || _seen $pacstall_k && not _seen $pacstall_p $pacstall_p_cmds $pacstall_p_grouped" -o PUp -d 'Disable and Upgrade'

complete -f -c pacstall -n "_seen $pacstall_p $pacstall_bp $pacstall_pk $pacstall_bpk && not _seen $pacstall_p_cmds" -o I -l install -d 'Install package'
complete -f -c pacstall -n "_seen $pacstall_p $pacstall_pk && not _seen $pacstall_p_cmds" -o Up -l upgrade -d 'Upgrade packages'

# Completions for K commands

complete -f -c pacstall -n "not _seen $pacstall_cmds || _seen $pacstall_p $pacstall_b $pacstall_bp && not _seen $pacstall_k $pacstall_k_cmds $pacstall_k_grouped" -o KI -d 'Install and Retain'
complete -f -c pacstall -n "not _seen $pacstall_cmds || _seen $pacstall_p && not _seen $pacstall_k $pacstall_k_cmds $pacstall_k_grouped" -o KUp -d 'Upgrade and Retain'

complete -f -c pacstall -n "_seen $pacstall_k $pacstall_bk $pacstall_pk $pacstall_bpk && not _seen $pacstall_k_cmds" -o I -l install -d 'Install package'
complete -f -c pacstall -n "_seen $pacstall_k $pacstall_pk && not _seen $pacstall_k_cmds" -o Up -l upgrade -d 'Upgrade packages'

# Completions for B commands

complete -f -c pacstall -n "not _seen $pacstall_cmds || _seen $pacstall_p $pacstall_k $pacstall_pk && not _seen $pacstall_b $pacstall_b_cmds $pacstall_b_grouped" -o BI -d 'Build package'

complete -f -c pacstall -n "_seen $pacstall_b $pacstall_bp $pacstall_bk $pacstall_bpk && not _seen $pacstall_b_cmds" -o I -l install -d 'Install package'

# Completions for PK commands
complete -f -c pacstall -n "_seen $pacstall_k_cmds && not _seen $pacstall_p $pacstall_k $pacstall_p_grouped" -o PK -d 'Disable and Retain'
complete -f -c pacstall -n "_seen $pacstall_k_cmds && not _seen $pacstall_p $pacstall_k $pacstall_p_grouped" -o KP -d 'Disable and Retain'


complete -f -c pacstall -n "_seen $pacstall_pk && not _seen $pacstall_k_cmds" -o I -l install -d 'Install package'
complete -f -c pacstall -n "_seen $pacstall_pk && not _seen $pacstall_k_cmds" -o Up -l upgrade -d 'Upgrade packages'

# Completion for B + P/K commands

complete -f -c pacstall -n "_seen $pacstall_b_cmds && not _seen $pacstall_b $pacstall_k $pacstall_bk $pacstall_b_grouped" -o BK -d 'Build and Retain'
complete -f -c pacstall -n "_seen $pacstall_b_cmds && not _seen $pacstall_p $pacstall_b $pacstall_bp $pacstall_b_grouped" -o BP -d 'Disable and Build'
complete -f -c pacstall -n "_seen $pacstall_b_cmds && not _seen $pacstall_p $pacstall_b $pacstall_k $pacstall_bk $pacstall_pk $pacstall_bpk $pacstall_b_grouped" -o BPK -d 'Disable and Retain'

complete -f -c pacstall -n "_seen $pacstall_pb && not _seen $pacstall_b_cmds" -o I -l install -d 'Install package'
complete -f -c pacstall -n "_seen $pacstall_bk && not _seen $pacstall_b_cmds" -o I -l install -d 'Install package'
complete -f -c pacstall -n "_seen $pacstall_pk && not _seen $pacstall_k_cmds" -o I -l install -d 'Install package'
complete -f -c pacstall -n "_seen $pacstall_bpk && not _seen $pacstall_p_cmds" -o I -l install -d 'Install package'
complete -f -c pacstall -n "_seen $pacstall_pk && not _seen $pacstall_b $pacstall_k_cmds" -o Up -l upgrade -d 'Upgrade packages'


# Command type lists
set -l package_cmds -I --install -S --search -D --download -PI -IP -KI -IK -BI -IB -KPI -KIP -PKI -PIK -IKP -IPK -BPI -BIP -PBI -PIB -IBP -IPB -KBI -KIB -BKI -BIK -IKB -IBK -BPKI -BKPI -PBKI -PKBI -KBPI -KPBI -BPIK -BKIP -PBIK -PKIB -KBIP -KPIB -BIPK -BIKP -PIBK -PIKB -KIBP -KIPB -IBPK -IBKP -IPBK -IPKB -IKBP -IKPB
set -l log_cmds -R -PR -RP --remove -L --list -Qi --query-info -T --tree
set -l pacscript_cmds -I --install -PI -IP -KI -IK -BI -IB -KPI -KIP -PKI -PIK -IKP -IPK -BPI -BIP -PBI -PIB -IBP -IPB -KBI -KIB -BKI -BIK -IKB -IBK -BPKI -BKPI -PBKI -PKBI -KBPI -KPBI -BPIK -BKIP -PBIK -PKIB -KBIP -KPIB -BIPK -BIKP -PIBK -PIKB -KIBP -KIPB -IBPK -IBKP -IPBK -IPKB -IKBP -IKPB

# Completion for the package related flags
complete -f -c pacstall -n "_seen $package_cmds" -a "(sed -e 's/\$/\/packagelist/' /usr/share/pacstall/repo/pacstallrepo | xargs -n 1 curl -s | sort -u)"

# Completion for the log related flags
complete -f -c pacstall -n "_seen $log_cmds" -a "(command ls -1aA /var/lib/pacstall/metadata)"

# Completion for the local pacscript flags
complete -f -c pacstall -n "_seen $pacscript_cmds" -a "(find -maxdepth 1 -type f -name '*.pacscript' | sed 's/.pacscript//g' | sed 's/.\///g')"

# vim:set ft=sh ts=4 sw=4 et:
