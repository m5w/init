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

_get_home () {
        # cf. <https://superuser.com/a/484330>
        getent passwd "$1"|cut -d: -f6
}

# This script needs to run as the superuser.  However, it also needs to run as
# the user.  sudo solves this problem by setting the environmental variable
# ``SUDO_USER`` to "the login name of the user who invoked sudo"[^1], and so,
# if this script is executed as the superuser with sudo, the following code
#
#     su "$SUDO_USER" << LF
#     echo 'Hello, world!'
#     LF
#
# would execute ``echo "Hello, world!"`` as the user.  This script could also
# be executed as a user other than the superuser with sudo with the
# ``-u user, --user=user`` option of sudo, but then, in the above code, su
# might (interactively) prompt for a password (but all commands in this script
# must be non-interactive), and, to run as the superuser, the script would have
# to execute ``su << LF`` instead of the first line of the above code, which,
# unless the user is the superuser, would also prompt for a password.
#
# terminal-logger uses ``HOME`` to determine where to look for a
# ``.terminal-logger`` directory, and trash-put appears to do the same to
# determine where to look for a ``Trash`` directory.  If terminal-logger does
# not find a ``.terminal-logger`` directory at ``"$HOME/.terminal-logger"``, it
# makes one.  This new directory has the same owner as the user as which
# terminal-logger runs.  If the user were to run this script as the superuser
# with sudo, but not on a login shell, ``HOME`` would still be the user's home
# directory, not that of the superuser.  Therefore, when this script would
# first invoke terminal-logger, terminal-logger would look in the user's home
# directory for a ``.terminal-logger`` directory, not find one, and make a new
# ``.terminal-logger`` directory under the user's home directory but owned by
# the superuser.  When the user later invokes terminal-logger, terminal-logger
# would find this directory and try to open the ``lock`` file, which is in the
# directory (at ``$HOME/.terminal-logger/lock``).  However, since the directory
# would be owned by the superuser, and terminal-logger is running as the user,
# terminal-logger would not have permission to open the ``lock`` file.  A
# similar problem would occur with trash-put, which appears to make a ``Trash``
# directory at ``"$HOME/.local/share/Trash"`` if it does not find one there and
# tries to open directories under this directory.  Therefore, the user must
# also execute this script on a login shell.  The script actually runs as the
# user by executing ``sudo -iu "$SUDO_USER" bash << LF`` instead of
# ``su "$SUDO_USER" << LF``, since the later would execute with ``HOME`` as the
# superuser's home directory, not that of the user.
#
# [^1]: cf. "ENVIRONMENT".  To read this section, type
#
#     man sudo
#
# and move to the first match of "ENVIRONMENT".

(($EUID == 0)) && [[ $HOME == $(_get_home 0) ]] && [[ -n $SUDO_USER ]] || {
echo "$0: You must invoke sudo to execute this program as the superuser on a login shell"
exit 1
}

# Install terminal-logger.  This script needs terminal-logger first to upgrade
# all of the installed software and then to install stow, which this script
# needs first to configure APT.

sudo -iu "$SUDO_USER" bash << LF

#
#     mkdir -p github.com/m5w
#     cd github.com/m5w
#
# The directory github.com/m5w/init should already exist.
cd github.com/m5w

git clone                                                                     \
        'https://github.com/m5w/terminal-logger.git'
LF
_sudo_home="$(_get_home "$SUDO_USER")"
cd "$_sudo_home/github.com/m5w/terminal-logger"
install -Dt /usr/local/bin terminal-logger
sudo -iu "$SUDO_USER" bash << LF
mkdir .terminal-logger
LF

# Upgrade all of the installed software.

#
#     terminal-logger apt-get -qy update
#
# The user should have had to have run
#
#     sudo apt-get update
#
# before installing git, which the user should have had to install before
# downloading this script.  Because the upgrade script performs this redundant
# and thus unnecessary update, this script does not use the upgrade script
# here.
terminal-logger apt-get -qy dist-upgrade
terminal-logger apt-get -qy --purge autoremove

# Install stow.

terminal-logger apt-get -qy install stow

# Configure APT.  It is necessary for APT to have the following configuration
# item[^1]
#
#     APT::Get::quiet "true";
#
# for the user to "Install drivers that are appropriate for automatic
# installation"[^2] by executing
# ``terminal-logger ubuntu-drivers autoinstall``, since ubuntu-drivers appears
# to invoke apt-get, but "-q" cannot be passed to the apt-get instance that
# ubuntu-drivers uses.
#
# This script also needs "Source code" to be "Downloadable from the
# Internet"[^3] to execute ``terminal-logger apt-get -y build-dep vim``.
#
# [^1]: cf. "-q, --quiet".  To read this section, execute the following command
#
#     man apt-get
#
# and move to the first match of "-q, --quiet".
#
# [^2]: cf. "Available commands".  To read this section, execute the following
# command.
#
#     ubuntu-drivers --help
#
# [^3]: cf. "Kubuntu Software".  To read this section, execute the following
# command.
#
#     kdesudo software-properties-kde

cd /etc/apt
git clone                                                                     \
        'https://github.com/m5w/etc-apt-stow.git'                             \
        stow

#
#     rm sources.list
#
# System files should be preserved, just in case.
terminal-logger apt-get -qy install trash-cli
sudo -iu "$SUDO_USER" bash << LF
mkdir -p .local/share/Trash
cd .local/share/Trash
mkdir files info
LF
trash-put sources.list

cd stow
stow apt

# "-qy" is no longer necessary; only "-y" is.

terminal-logger apt-get -y update

# Install SMART Monitoring Tools.

terminal-logger apt-get -y install                                            \
        bsd-mailx                                                             \
        smartmontools                                                         \
        ssmtp

# Configure SMART Monitoring Tools.

cd /etc
git clone                                                                     \
        'https://github.com/m5w/etc-stow.git'                                 \
        stow
trash-put smartd.conf
cd stow
stow smartd

# Configure GNU GRUB.

cd /etc/default
git clone                                                                     \
        'https://github.com/m5w/etc-default-stow.git'                         \
        stow
trash-put grub
cd stow
stow grub
update-grub

# Install NTP.

terminal-logger apt-get -y install                                            \
        ntp                                                                   \
        ntp-doc

# Set the clock.

service ntp stop
ntpd -gq
service ntp start

# Install the backup and upgrade scripts.

sudo -iu "$SUDO_USER" bash << LF
git clone --recursive                                                         \
        'https://github.com/m5w/stow.git'
LF
cd "$_sudo_home/stow/backup"
install -Dt /usr/local/bin backup
cd "$_sudo_home/stow/upgrade"
install -Dt /usr/local/bin upgrade

# Install vim.

terminal-logger apt-get -y build-dep vim
terminal-logger apt-get -y install                                            \
        python-dbg                                                            \
        python-dev                                                            \
        python-doc
sudo -iu "$SUDO_USER" bash << LF
cd github.com/m5w
git clone                                                                     \
        'https://github.com/m5w/vim.git'
cd vim
git remote add upstream                                                       \
        'https://github.com/vim/vim.git'
./configure                                                                   \
        --with-features=huge                                                  \
        --enable-luainterp=yes                                                \
        --enable-perlinterp=yes                                               \
        --enable-pythoninterp=yes                                             \
        --enable-tclinterp=yes                                                \
        --enable-rubyinterp=yes                                               \
        --enable-gui=gtk2                                                     \
        --with-python-config-dir=\
/usr/lib/python2.7/config-x86_64-linux-gnu
make
LF
cd "$_sudo_home/github.com/m5w/vim"
make install

# Configure vim.

# ClangFormat
sudo -iu "$SUDO_USER" bash << LF
cd stow
stow clang-format
LF
terminal-logger apt-get -y install clang-format

# Eclipse
terminal-logger apt-get -y install openjdk-8-doc
sudo -iu "$SUDO_USER" bash << LF
cd Downloads
wget                                                                          \
        'https://mirrors.xmission.com/eclipse/technology/epp/downloads/release/neon/3/eclipse-java-neon-3-linux-gtk-x86_64.tar.gz'
LF
cd "$_sudo_home/Downloads"
tar xf eclipse-java-neon-3-linux-gtk-x86_64.tar.gz -C /opt

# to-do: Eclim
terminal-logger apt-get -y install openjdk-8-jdk
sudo -iu "$SUDO_USER" bash << LF
cd Downloads
wget                                                                          \
        'https://github.com/ervandew/eclim/releases/download/2.6.0/eclim_2.6.0.jar'
LF

# vim-plug
terminal-logger apt-get -y install curl

# YCM-Generator
terminal-logger apt-get -y install clang

# color_coded
terminal-logger apt-get -y install                                            \
        build-essential                                                       \
        cmake                                                                 \
        cmake-doc                                                             \
        libclang-3.9-dev                                                      \
        libclang1-3.9-dbg                                                     \
        libncurses5-dbg                                                       \
        libncurses5-dev                                                       \
        libpthread-workqueue-dev                                              \
        zlib1g-dbg                                                            \
        zlib1g-dev
_vim_version="$(vim --version)"
_liblua_version_pattern='-llua([0-9]\.[0-9])'
[[ $_vim_version =~ $_liblua_version_pattern ]]
terminal-logger apt-get -y install "liblua${BASH_REMATCH[1]}-dev"

# YouCompleteMe
terminal-logger apt-get -y install                                            \
        python3-dbg                                                           \
        python3-dev                                                           \
        python3-doc
terminal-logger apt-get -y install                                            \
        mono-complete                                                         \
        mono-dbg

# vim-flake8
terminal-logger apt-get -y install flake8

sudo -iu "$SUDO_USER" bash << LF
mkdir -p .vim/after/ftplugin
cd .vim/after
mkdir -p syntax/tex
cd ~/stow
stow vim
vim +qa
LF

# yapf
terminal-logger apt-get -y install python3-pip
terminal-logger pip3 -q install yapf

# Configure GNU Bash and Git.

sudo -iu "$SUDO_USER" bash << LF
trash-put                                                                     \
        .bashrc                                                               \
        .profile
cd .config
trash-put                                                                     \
        kglobalshortcutsrc                                                    \
        khotkeysrc                                                            \
        konsolerc                                                             \
        kwinrulesrc                                                           \
        powerdevilrc                                                          \
        powermanagementprofilesrc
cd ../stow
stow                                                                          \
        bash                                                                  \
        git                                                                   \
        kglobalshortcuts                                                      \
        khotkeys                                                              \
        klipper                                                               \
        konsole                                                               \
        kwinrules                                                             \
        powerdevil                                                            \
        powermanagementprofiles
LF

# Configure Git for the superuser.

cd
git clone --recursive                                                         \
        'https://github.com/m5w/root-stow.git'                                \
        stow
cd stow
stow git

# Install Apertium.

terminal-logger apt-get -y install                                            \
        automake                                                              \
        flex                                                                  \
        flex-doc                                                              \
        gawk                                                                  \
        gawk-doc                                                              \
        libpcre3-dbg                                                          \
        libpcre3-dev                                                          \
        libtool                                                               \
        libtool-doc                                                           \
        libxml2-dbg                                                           \
        libxml2-dev                                                           \
        libxml2-doc                                                           \
        pkg-config                                                            \
        subversion                                                            \
        xsltproc
sudo -iu "$SUDO_USER" bash << LF
mkdir -p svn.code.sf.net/p/apertium/svn/trunk
LF
for _directory in                                                             \
        lttoolbox                                                             \
        apertium                                                              \
        apertium-lex-tools
do
        sudo -iu "$SUDO_USER" bash << LF
cd svn.code.sf.net/p/apertium/svn/trunk
svn co                                                                        \
        "https://svn.code.sf.net/p/apertium/svn/trunk/$_directory"
cd "$_directory"
./autogen.sh
make
LF
        cd "$_sudo_home/svn.code.sf.net/p/apertium/svn/trunk/$_directory"
        make install
        ldconfig
done
sudo -iu "$SUDO_USER" bash << LF
cd svn.code.sf.net/p/apertium/svn/trunk
svn co                                                                        \
        'https://svn.code.sf.net/p/apertium/svn/trunk/apertium-tools'
LF

# Install Matxin.

terminal-logger apt-get -y install                                            \
        libxslt1-dbg                                                          \
        libxslt1-dev
sudo -iu "$SUDO_USER" bash << LF
cd Downloads
wget                                                                          \
        'https://apertium.projectjj.com/apt/install-nightly.sh'
chmod +x install-nightly.sh
LF
"$_sudo_home/Downloads/install-nightly.sh"
terminal-logger apt-get -y install                                            \
        foma-bin                                                              \
        libfoma0-dev

# upstream
sudo -iu "$SUDO_USER" bash << LF
cd github.com
mkdir matxin
cd matxin
git clone                                                                     \
        'https://github.com/matxin/matxin.git'
cd matxin
./autogen.sh
make
LF
cd "$_sudo_home/github.com/matxin/matxin"
make install

# origin
sudo -iu "$SUDO_USER" bash << LF
cd github.com/m5w
git clone                                                                     \
        'https://github.com/m5w/matxin.git'
cd matxin
git remote add upstream                                                       \
        'https://github.com/matxin/matxin.git'
./autogen.sh
make
LF

# matxin-lineariser
sudo -iu "$SUDO_USER" bash << LF
cd github.com
mkdir moses-smt
cd moses-smt
git clone                                                                     \
        'https://github.com/moses-smt/mosesdecoder.git'
LF
terminal-logger apt-get -y install                                            \
        python3-matplotlib                                                    \
        python3-nltk                                                          \
        python3-numpy
terminal-logger pip3 -q install scikit-learn
terminal-logger apt-get -y install                                            \
        ant                                                                   \
        ant-doc
sudo -iu "$SUDO_USER" bash << LF
cd github.com/matxin
git clone                                                                     \
        'https://github.com/matxin/matxin-lineariser.git'
cd matxin-lineariser/tg
ant
LF
sudo -iu "$SUDO_USER" bash << LF
cd github.com
mkdir ufal
cd ufal
git clone                                                                     \
        'https://github.com/ufal/udpipe.git'
cd udpipe/src
make
LF

# matxin-lat
sudo -iu "$SUDO_USER" bash << LF
cd github.com/m5w
git clone                                                                     \
        'https://github.com/m5w/matxin-lat.git'
LF

# matxin-lat-eng
sudo -iu "$SUDO_USER" bash << LF
cd github.com/m5w
git clone                                                                     \
        'https://github.com/m5w/matxin-lat-eng.git'
cd matxin-lat-eng
lt-comp lr matxin-lat-eng.lat-eng.dix lat-eng.autobil.bin
matxin-preprocess-transfer matxin-lat-eng.lat-eng.t1x lat-eng.t1x.bin
LF

# matxin-eng
sudo -iu "$SUDO_USER" bash << LF
cd github.com/m5w
git clone                                                                     \
        'https://github.com/m5w/matxin-eng.git'
cd matxin-eng
lt-comp rl matxin-eng.eng.dix eng.autogen.bin
matxin-preprocess-generate matxin-eng.eng.gnx eng.gnx.bin
LF

# Install SPASM-ng.

terminal-logger apt-get -y install                                            \
        libgmp-dev                                                            \
        libssl-dev                                                            \
        libssl-doc
sudo -iu "$SUDO_USER" bash << LF
cd github.com
mkdir alberthdev
cd alberthdev
git clone                                                                     \
        'https://github.com/alberthdev/spasm-ng.git'
cd spasm-ng
make
LF
cd "$_sudo_home/github.com/alberthdev/spasm-ng"
make install

# Install BinPac8x.

sudo -iu "$SUDO_USER" bash << LF
cd Downloads
wget -O binpac8x.zip                                                          \
        'https://www.cemetech.net/scripts/countdown.php?/win/asm/binpac8x.zip&path=archives'
mkdir binpac8x
cd binpac8x
unzip ../binpac8x.zip
chmod +x binpac8x.py
LF
cd "$_sudo_home/Downloads/binpac8x"
install -Dt /usr/local/bin binpac8x.py

# Install KeePass

terminal-logger apt-get -y install                                            \
        keepass2                                                              \
        keepass2-doc                                                          \
        xdotool

# Install Spotify.

terminal-logger apt-key adv                                                   \
        --keyserver \
'hkp://keyserver.ubuntu.com:80'                                               \
        --recv-keys \
0DF731E45CE24F27EEEB1450EFDC8610341D9410
cat > /etc/apt/sources.list.d/spotify.list << LF
deb http://repository.spotify.com stable non-free
LF
terminal-logger apt-get update
terminal-logger apt-get -y install spotify-client

# Install TeX Live 2017.

terminal-logger apt-get -y install                                            \
        gnuplot                                                               \
        gnuplot-doc                                                           \
        perl-doc                                                              \
        python3-pygments

sudo -iu "$SUDO_USER" bash << LF
cd Downloads
wget                                                                          \
        'http://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz'
mkdir install-tl-unx
cd install-tl-unx
tar xf ../install-tl-unx.tar.gz --strip-components=1
ln -s ~/github.com/m5w/init/texlive.profile
LF
EDITOR=ed visudo -f /etc/sudoers.d/install-tl << LF
a
$SUDO_USER $(hostname) = NOPASSWD: $_sudo_home/Downloads/install-tl-unx/install-tl
.
wq
LF
sudo -iu "$SUDO_USER" bash << LF
cd Downloads/install-tl-unx
sudo ./install-tl --profile=texlive.profile
LF
rm /etc/sudoers.d/install-tl

# Install XZ Utils 5.2

sudo -iu "$SUDO_USER" bash << LF
cd Downloads
wget                                                                          \
        'https://downloads.sourceforge.net/project/lzmautils/xz-5.2.2.tar.gz'
tar xf xz-5.2.2.tar.xz
cd xz-5.2.2
./configure
make
LF
cd "$_sudo_home/Downloads/xz-5.2.2"
make install
ldconfig

sudo -iu "$SUDO_USER" bash << LF
tlmgr init-usertree
tlmgr install                                                                 \
        minted                                                                \
        mla-paper
LF

# Install VirtualBox

sudo -iu "$SUDO_USER" bash << LF
cd Downloads
wget                                                                          \
        'https://www.virtualbox.org/download/oracle_vbox.asc'
wget                                                                          \
        'https://www.virtualbox.org/download/oracle_vbox_2016.asc'
LF
cat > /etc/apt/sources.list.d/virtualbox.list << LF
deb http://download.virtualbox.org/virtualbox/debian xenial contrib
LF
terminal-logger apt-key add "$_sudo_home/Downloads/oracle_vbox.asc"
terminal-logger apt-key add "$_sudo_home/Downloads/oracle_vbox_2016.asc"
terminal-logger apt-get update
terminal-logger apt-get -y install                                            \
        dkms                                                                  \
        virtualbox-5.1

# Install WeeChat

terminal-logger apt-get -y install                                            \
        weechat                                                               \
        weechat-doc                                                           \
        weechat-scripts
sudo -iu "$SUDO_USER" bash << LF
mkdir -p .weechat/perl/autoload
cd .weechat/perl/autoload
ln -s /usr/share/weechat/perl/iset.pl
LF

# Install packages.

terminal-logger apt-get -y install                                            \
        acpidump                                                              \
        avahi-utils                                                           \
        baobab                                                                \
        bleachbit                                                             \
        chkrootkit                                                            \
        clang-tidy                                                            \
        dconf-cli                                                             \
        dos2unix                                                              \
        easytag                                                               \
        flashplugin-installer                                                 \
        geda                                                                  \
        gimp                                                                  \
        git-doc                                                               \
        git-gui                                                               \
        git-svn                                                               \
        gnome-disk-utility                                                    \
        gstreamer1.0-fluendo-mp3                                              \
        gufw                                                                  \
        idle3                                                                 \
        iotop                                                                 \
        libboost-all-dev                                                      \
        libboost-dbg                                                          \
        libboost-doc                                                          \
        lilypond                                                              \
        lilypond-doc                                                          \
        lldb                                                                  \
        markdown                                                              \
        nasm                                                                  \
        p7zip-full                                                            \
        pandoc                                                                \
        pastebinit                                                            \
        pavucontrol                                                           \
        proot                                                                 \
        python-visual                                                         \
        python3-lxml                                                          \
        python3-pyftpdlib                                                     \
        qemu-user                                                             \
        screen                                                                \
        tcl-doc                                                               \
        thunderbird                                                           \
        tilp2                                                                 \
        timidity                                                              \
        usb-creator-kde                                                       \
        valgrind

cat << \LF
# Installing drivers may fail.
sudo terminal-logger ubuntu-drivers autoinstall

java -jar ~/Downloads/eclim_2.6.0.jar

# Installing steam requires (interactively) accepting a license agreement.
sudo terminal-logger apt-get install steam
LF
