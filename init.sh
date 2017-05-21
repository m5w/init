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
# install terminal-logger.

# Actually, those aliases aren't useful in this script---the ones that pertain
# to some of what we need to do (update and install packages) automatically
# invoke sudo and require user confirmation. Nonetheless, we still need stow to
# configure GNU GRUB, and we still need terminal-logger foremost to update all
# of the installed software.

su "$SUDO_USER" <<\LF
#cd "~$SUDO_USER"  # This was not originally in a heredoc. (It should have been
                   # in one, though, since we want to clone repositories as
                   # the user.)
#mkdir -p github.com/m5w
#cd github.com/m5w
cd ~/github.com/m5w  # github.com/m5w/init/ should already exist.
git clone https://github.com/m5w/terminal-logger.git
LF
# <https://superuser.com/a/484330>
SUDO_HOME="$(getent passwd $SUDO_USER|cut -d: -f6)"
cd "$SUDO_HOME/github.com/m5w/terminal-logger"
install -Dt /usr/local/bin terminal-logger

# Update all of the installed software. We should not use my upgrade script
# because it performs an unnecessary update (cf. below).

#terminal-logger apt-get -y update
#terminal-logger apt-get -y dist-upgrade  # The user should have had to have
                                          # run
                                          #
                                          #         sudo apt-get -q update
                                          #
                                          # before installing git, which should
                                          # be installed.
terminal-logger apt-get -y --purge autoremove

# Install stow.

terminal-logger apt-get -y install stow

# Install my backup and upgrade scripts.

su "$SUDO_USER" <<\LF
cd ~
git clone https://github.com/m5w/stow.git
LF
cd "$SUDO_HOME/stow/backup"
install -Dt /usr/local/bin backup
cd "$SUDO_HOME/stow/upgrade"
install -Dt /usr/local/bin upgrade

# Configure GNU GRUB.

cd /etc/default
git clone https://github.com/m5w/etc-default-stow.git stow
#rm grub
terminal-logger apt-get -y install trash-cli
trash-put grub  # We should preserve system files, just in case.
cd stow
git checkout VirtualBox
stow grub
update-grub

# Configure APT. We need source code to run
#
#         terminal-logger apt-get -y build-dep vim
#

cd /etc/apt
git clone https://github.com/m5w/etc-apt-stow.git stow
trash-put sources.list
cd stow
stow apt
terminal-logger apt-get -y update

# Install vim.

terminal-logger apt-get -y build-dep vim
su "$SUDO_USER" <<\LF
cd ~/github.com/m5w
git clone https://github.com/m5w/vim.git
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

# plug
terminal-logger apt-get -y install curl

# YCM-Generator
terminal-logger apt-get -y install                                           \
        clang                                                                \
        python

# color_coded
terminal-logger apt-get -y install                                           \
        cmake                                                                \
        libclang-dev                                                         \
        libncurses-dev                                                       \
        libpthread-workqueue-dev                                             \
        libz-dev                                                             \
        xz-utils
#terminal-logger apt-get -y install "liblua$(
#vim --version|
#grep -- '-llua[1-9]\.[0-9]'|
#sed 's/.*-llua\([1-9]\.[0-9]\).*/\1/')-dev"
VIM_VERSION="$(vim --version)"
LIBLUA_VERSION_PATTERN='-llua([0-9]\.[0-9])'
[[ $VIM_VERSION =~ $LIBLUA_VERSION_PATTERN ]]
terminal-logger apt-get -y install "liblua${BASH_REMATCH[1]}-dev"

# YouCompleteMe
terminal-logger apt-get -y install                                           \
        python-dev                                                           \
        python3-dev
