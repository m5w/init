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

# This script needs to run as the superuser. However, it also needs to run as
# the user.  sudo solves this problem by setting the environmental variable
# SUDO_USER to ``the login name of the user who invoked sudo"[^1], and so, if
# this script is executed (as the superuser) with sudo, it could run
#
#     su "$SUDO_USER" << LF
#     echo "Hello, world!"
#     LF
#
# to execute ``echo "Hello, world!"`` as the user. (This script could also be
# executed as a user other than the superuser with sudo with the
# ``-u user, --user=user`` option of sudo, but then, if the script were to run
# the above code, su would (interactively) prompt for a password. All commands
# in this script must be non-interactive.)
#
# terminal-logger uses HOME to determine where to look for a .terminal-logger
# directory (at ``"$HOME/.terminal-logger"``), and trash-put appears to do the
# same to determine where to look for the Trash. If terminal-logger does not
# find a .terminal-logger directory where it first looks, it makes one. This
# new .terminal-logger directory has the same owner as the user as which
# terminal-logger runs. If the user runs this script as the superuser, but not
# on a login shell with sudo, HOME is still the user's home directory, not that
# of the superuser. Therefore, when this script would first run
# terminal-logger, terminal-logger would look in the user's home directory for
# a .terminal-logger directory, not find one, and make a new .terminal-logger
# directory under the user's home directory but owned by the superuser. When
# the user would later run terminal-logger, terminal-logger would find this
# newly-made directory and try to open the lock file, which is under the
# directory. However, since the directory is owned by the superuser, and
# terminal-logger would be running as the user, terminal-logger would not have
# permission to open the lock file. A similar problem would occur with
# trash-put, which appears to make Trash at ``"$HOME/.local/share/Trash"`` if
# Trash does not already exist and tries to open directories under Trash.
# Therefore, the user must also execute this script on a login shell. The
# script actually runs as the user by running ``sudo -iu "$SUDO_USER" << LF``
# instead of ``su "$SUDO_USER" << LF``, since the later would execute with HOME
# as the superuser's home directory.

_get_home () {
        # cf. <https://superuser.com/a/484330>
        getent passwd "$1"|cut -d: -f6
}

(($EUID == 0)) && [[ $HOME == $(_get_home 0) ]] && [[ -n $SUDO_USER ]] || {
echo "$0: You must invoke sudo to execute this program as the superuser on a login shell"|fold --spaces --width=79
exit 1
}

# Install terminal-logger. This script needs it first to upgrade all of the
# installed software by running
#
#         terminal-logger apt-get -qy dist-upgrade
#         terminal-logger apt-get -qy --purge autoremove
#
# and install stow, which this script needs first to configure APT.

sudo -iu "$SUDO_USER" bash << LF

#
#         mkdir -p github.com/m5w
#         cd github.com/m5w
#
# github.com/m5w/init/ should already exist.
cd github.com/m5w

git clone https://github.com/m5w/terminal-logger.git terminal-logger
LF
SUDO_HOME="$(_get_home "$SUDO_USER")"
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

terminal-logger apt-get -qy dist-upgrade
terminal-logger apt-get -qy --purge autoremove

# Install stow.

terminal-logger apt-get -qy install stow

# Configure APT.
#
# cf. "-q, --quiet". To read this section, type
#
#         man apt-get
#
# and move to the first match of "-q, --quiet".
#
# cf. "Available commands". To read this section, type
#
#         ubuntu-drivers --help
#
# This script needs
#
#         APT::Get::quiet "true";
#
# to ``Install drivers that are appropriate for automatic installation" by
# running
#
#         terminal-logger ubuntu-drivers autoinstall
#
# since ubuntu-drivers uses apt-get, but "-q" cannot be passed on to the
# apt-get instance that ubuntu-drivers uses.
#
# cf. "Kubuntu Software". To read this section, type
#
#         kdesudo software-properties-kde
#
# This script also needs ``Source code" to be ``Downloadable from the Internet"
# to run
#
#         terminal-logger apt-get -y build-dep vim
#

cd /etc/apt
git clone https://github.com/m5w/etc-apt-stow.git stow

#
#         rm sources.list
#
# System files should be preserved, just in case.
terminal-logger apt-get -y install trash-cli
trash-put sources.list

cd stow
stow apt

# "-qy" is no longer necessary; only "-y" is.

terminal-logger apt-get -y update

terminal-logger ubuntu-drivers autoinstall

# Configure GNU GRUB.

cd /etc/default
git clone https://github.com/m5w/etc-default-stow.git stow
trash-put grub
cd stow
stow grub
update-grub

# Install the backup and upgrade scripts.

sudo -iu "$SUDO_USER" bash << LF
git clone https://github.com/m5w/stow.git stow
LF
cd "$SUDO_HOME/stow/backup"
install -Dt /usr/local/bin backup
cd "$SUDO_HOME/stow/upgrade"
install -Dt /usr/local/bin upgrade

# Install vim.

terminal-logger apt-get -y build-dep vim
sudo -iu "$SUDO_USER" bash << LF
cd github.com/m5w
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
sudo -iu "$SUDO_USER" bash << LF
cd stow
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

sudo -iu "$SUDO_USER" bash << LF
mkdir -p ~/.vim/after/ftplugin
cd stow
stow vim
vim +qa
LF

sudo -iu "$SUDO_USER" bash << LF
trash-put                                                                     \
        .bashrc                                                               \
        .profile
cd stow
stow                                                                          \
        bash                                                                  \
        git
LF
