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

# This script needs root permissions to install programs and packages. However,
# it also needs to run as the user and under the user's home directory.
# Therefore, the user must run this script with sudo so that this script can
# run as the user with
#
#         su "$SUDO_USER" << LF
#
# and use
#
#         "$(getent passwd "$SUDO_USER"|cut -d: -f6)"
#
# to get the user's home directory.

[[ "$EUID" -eq 0 ]] && [[ -n "$SUDO_USER" ]] || {
echo "$0: You must use sudo to execute this program as the superuser"
exit 1
}

# Install terminal-logger. This script needs it to upgrade all of the installed
# software by running
#
#         terminal-logger apt-get -qy dist-upgrade
#         terminal-logger apt-get -qy --purge autoremove
#
# and install stow, which this script needs first to configure GNU GRUB.

su "$SUDO_USER" << LF

#
#         cd ~
#         mkdir -p github.com/m5w
#         cd github.com/m5w
# 
# github.com/m5w/init/ should already exist.
cd ~/github.com/m5w

git clone https://github.com/m5w/terminal-logger.git terminal-logger
LF

# cf. <https://superuser.com/a/484330>.
SUDO_HOME="$(getent passwd "$SUDO_USER"|cut -d: -f6)"

cd "$SUDO_HOME/github.com/m5w/terminal-logger"
install -Dt /usr/local/bin terminal-logger

# Upgrade all of the installed software.

#
#         terminal-logger apt-get -qy update
#
# The user should have had to have run
#
#         sudo apt-get update
#
# before installing git, which should be installed. Because the upgrade script
# performs this redundant and thus unnecessary update, this script does not use
# the upgrade script.

#terminal-logger apt-get -qy dist-upgrade
terminal-logger apt-get -qy --purge autoremove

# Install stow.

terminal-logger apt-get -qy install stow

# Configure GNU GRUB.

cd /etc/default
git clone https://github.com/m5w/etc-default-stow.git stow

#
#         rm grub
#
# System file should be preserved, just in case.
terminal-logger apt-get -qy install trash-cli
trash-put grub

cd stow
git checkout VirtualBox
stow grub
update-grub

# Install the backup and upgrade scripts.

su "$SUDO_USER" << LF
cd ~
git clone https://github.com/m5w/stow.git stow
LF
cd "$SUDO_HOME/stow/backup"
install -Dt /usr/local/bin backup
cd "$SUDO_HOME/stow/upgrade"
install -Dt /usr/local/bin upgrade

# Configure APT. We need source code to run
#
#         terminal-logger apt-get -y build-dep vim
#

cd /etc/apt
git clone https://github.com/m5w/etc-apt-stow.git stow
trash-put sources.list
cd stow
stow apt

# "-qy" is no longer necessary; only "-y" is.

terminal-logger apt-get -y update

# Install vim.

terminal-logger apt-get -y build-dep vim
su "$SUDO_USER" << LF
cd ~/github.com/m5w
git clone https://github.com/m5w/vim.git vim
cd vim
./configure                                                                   \
        --with-features=huge                                                  \
        --enable-luainterp=yes                                                \
        --enable-perlinterp=yes                                               \
        --enable-python3interp=yes                                            \
        --enable-tclinterp=yes                                                \
        --enable-rubyinterp=yes                                               \
        --enable-gui=gtk2                                                     \
        --with-python3-config-dir=\
/usr/lib/python3.5/config-3.5m-x86_64-linux-gnu
make
LF
cd "$SUDO_HOME/github.com/m5w/vim"
make install

# Configure vim.

# ClangFormat
su "$SUDO_USER" << LF
cd ~/stow
stow clang-format
LF
terminal-logger apt-get -y install clang-format

# to-do: eclim

# vim-plug
terminal-logger apt-get -y install curl

# YCM-Generator
terminal-logger apt-get -y install                                            \
        clang                                                                 \
        python

# color_coded
terminal-logger apt-get -y install                                            \
        cmake                                                                 \
        libclang-dev                                                          \
        libncurses-dev                                                        \
        libpthread-workqueue-dev                                              \
        libz-dev                                                              \
        xz-utils
VIM_VERSION="$(vim --version)"
LIBLUA_VERSION_PATTERN='-llua([0-9]\.[0-9])'
[[ $VIM_VERSION =~ $LIBLUA_VERSION_PATTERN ]]
terminal-logger apt-get -y install "liblua${BASH_REMATCH[1]}-dev"

# YouCompleteMe
terminal-logger apt-get -y install                                            \
        python-dev                                                            \
        python3-dev

su "$SUDO_USER" << LF
mkdir -p ~/.vim/after/ftplugin
cd ~/stow
stow vim
vim +qa
LF

su "$SUDO_USER" << LF
cd ~/stow
stow                                                                          \
        bash                                                                  \
        git
