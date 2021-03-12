#!/usr/bin/env bash

# Run this script after system and desktop are already installed

systemctl status systemd-homed
echo "Be sure to start and enable systemd-homed (as root) or else sudo may not work properly"
echo "Also, reinstall pambase if necessary `pacman -S pambase`"
echo "Type any to continue..." ; read empty

## PERSONAL DIRECTORIES AND RESOURCES
echo "Making personal subdirectories..."
mkdir tmp repos build 

# Pick a host to get stuff from on the local network
echo "Download home directory files from what host on network?"; read whathost

# get ssh keys...
scp -o StrictHostKeyChecking=no -r dsj@"$whathost".lan:.ssh .

# clone the latest dotfiles
git clone https://github.com/deepbsd/dotfiles.git

#scp -o StrictHostKeyChecking=no -r dsj@"$whathost".lan:{adm,dotfiles,.vim,public_html,sounds,.gkrellm2,wallpaper,wallpaper1,bin,.ssh,.gnupg,Music} .
scp -Br dsj@"$whathost".lan:{adm,.vim,public_html,sounds,.gkrellm2,wallpaper,wallpaper1,bin,.gnupg,Music} .

# SSH-AGENT SERVICE
echo "Start the ssh-agent service..."
eval $(ssh-agent)
ls ~/.ssh/* ; echo "Add which key? "; read key_name
ssh-add ~/.ssh/"$key_name"

## INSTALL DVD SUPPORT, GKRELLM, MLOCATE
sudo pacman -S libdvdread libdvdcss libdvdnav gkrellm mlocate fzf
echo "updating locate database..."
sudo updatedb

## INSTALL POWERLINE
$(which powerline >/dev/null) || sudo pacman -S powerline powerline-fonts

## CHECK FOR OLD FAITHFULS
$(which gkrellm) || sudo pacman -S gkrellm
[[ -f /opt/anaconda/bin/anaconda-navigator ]] || yay -S anaconda

## INSTALL DEV STUFF 
sudo pacman -S  ruby nodejs npm npm-check-updates gvim mlocate gkrellm

## DOTFILES
cp ~/.bashrc ~/.bashrc.orig
cp ~/.bash_profile ~/.bash_profile.orig
ln -sf ~/dotfiles/.bashrc .
ln -sf ~/dotfiles/.bash_profile .
ln -sf ~/dotfiles/.vimrc .

# NVM
mkdir $HOME/.nvm
[[ -x $(which git &>/dev/null) ]] && cd && git clone https://github.com/nvm-sh/nvm.git .nvm/.
[[ -d $HOME/.nvm ]] && cd ~/.nvm && source ./nvm.sh && cd

## INSTALL YAY  ## Do this last because of intermittant errors with yay-git
echo "Installing yay: "
cd ~/build
git clone https://aur.archlinux.org/yay-git.git
cd yay-git
makepkg -si
cd

yay -S paru

## REPLACE GNOME_TERMINAL WITH TRANSPARENCY VERSION (and mate-terminal)
yay -S gnome-terminal-transparency mate-terminal 

## INSTALL CHROME and ORANCHELO ICONS AND BREEZE CURSOR
yay -S google-chrome oranchelo-icon-theme-git xcursor-breeze





