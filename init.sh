#!/bin/bash

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -eo pipefail
unalias -a

# We want to configure the user's home directory, not root's. However, we
# require root permissions. Therefore, the user must run this script with sudo.

[[ "$EUID" -eq 0 ]] && [[ -n "$SUDO_USER" ]] || {
echo "$0: You must use sudo to execute this program as the superuser"
exit 1
}

# Really, we'd like to clone my dotfiles, stow .bash_aliases, and source it so
# that we could use my aliases henceforth. However, we first need to install
# stow, and we log all installations. Therefore, we first must clone and
# install logger.

# Actually, those aliases aren't useful in this script---the ones that pertain
# to some of what we need to do (update and install packages) automatically
# invoke sudo and require user confirmation. Nonetheless, we still need stow to
# configure GNU GRUB, and we still need logger foremost to update all of the
# installed software.

#cd "~$SUDO_USER"
#mkdir -p github.com/m5w
#cd github.com/m5w
cd "~$SUDO_USER/github.com/m5w"  # github.com/m5w/init/ should already exist.
git clone https://github.com/m5w/logger
cd logger
install -Dt /opt/logger/bin logger.sh

# Add /opt/logger/bin to the PATH so that we can use logger. /etc/profile will
# do this once we stow it, but we need logger before we can stow anything, and
# /etc/profile checks if directories exist before adding them to the PATH
# anyway, so we would have to source it after each installation to /opt/, which
# would lead to duplicate directories in the PATH. Therefore, we add
# directories manually to the PATH each time in this script.

PATH="/opt/logger/bin:$PATH"

# Update all of the installed software. We cannot use software-updater for
# reasons similar to why my aliases are not useful.

#logger.sh apt-get -qy update
logger.sh apt-get -qy dist-upgrade  # The user should have had to have run
                                    #
                                    #         sudo apt-get -q update
                                    #
                                    # to install git, which should be
                                    # installed.
logger.sh apt-get --qy --purge autoremove

# Install stow.

logger.sh apt-get -qy install stow
