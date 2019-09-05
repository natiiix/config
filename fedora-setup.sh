#!/bin/sh

# Stop on any error
set -e

# Update existing packages
sudo dnf -y update

# Install all commonly used packages
sudo dnf -y install wget curl bash htop vim gvim nano git gcc make ShellCheck python3.7 python3-devel python3-virtualenv ncurses ncurses-devel firefox gnome-tweaks postgresql-server postgresql-contrib libxcrypt-compat golang

# Enable PostgreSQL server daemon
sudo systemctl enable postgresql

# Initialize PostgreSQL database (ignore error if database has already been initialized)
sudo postgresql-setup --initdb --unit postgresql || true

# Make soft links for Python:
#   python -> python3
#   pip -> pip3
sudo ln -sf /usr/bin/python3 /usr/bin/python
sudo ln -sf /usr/bin/pip3 /usr/bin/pip

# Update pip3 and install some commonly used Python packages
sudo pip3 install --upgrade pip pylint autopep8 flask easy-postgres

# Set hostname
sudo sh -c 'echo "imeixner-fedora" > /etc/hostname'

# Set GOPATH
mkdir -p ~/go
echo 'export GOPATH=~/go' >> ~/.bashrc
source ~/.bashrc

# Download Vim configuration file
wget https://raw.githubusercontent.com/natiiix/config/master/.vimrc -O ~/.vimrc

# Generate an SSH key (this can be used for GitHub, GitLab, etc.)
[ -f ~/.ssh/id_rsa ] || ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "natiwastaken@gmail.com"

# Configure Git
git config --global user.name "Ivo Meixner"
git config --global user.email "natiwastaken@gmail.com"
git config --global core.eol lf
git config --global core.autocrlf false

# Install Visual Studio Code
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'

dnf check-update
sudo dnf -y install code

# Install most commonly used VSCode extensions
# code --list-extensions | sed 's/^/code --install-extension /'
code --install-extension doublefint.pgsql
code --install-extension eamodio.gitlens
code --install-extension ms-python.python
code --install-extension ms-vsliveshare.vsliveshare
code --install-extension njpwerner.autodocstring
code --install-extension VisualStudioExptTeam.vscodeintellicode
code --install-extension vscode-icons-team.vscode-icons
code --install-extension zhuangtongfa.Material-theme

echo '---- Jobs done! :-) ----'

