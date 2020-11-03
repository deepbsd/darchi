#!/usr/bin/env bash

# Run this script after system and desktop are already installed

## PERSONAL DIRECTORIES AND RESOURCES
echo "Making personal subdirectories..."
mkdir tmp repos build
echo "Download home directory files from what host on network?"; read whathost
scp -r dsj@"$whathost".lan:{adm,dotfiles,.vim,public_html,sounds,.gkrellm2,wallpaper,wallpaper1,bin,.ssh,.gnupg,Music} .


## INSTALL YAY
echo "Installing yay: "
cd ~/build
git clone https://aur.archlinux.org/yay-git.git
cd yay-git
makepkg -si
cd

## INSTALL DVD SUPPORT, GKRELLM, MLOCATE
sudo pacman -S libdvdread libdvdcss libdvdnav gkrellm mlocate fzf

## REPLACE GNOME_TERMINAL WITH TRANSPARENCY VERSION (and mate-terminal)
yay -S gnome-terminal-transparency mate-terminal 

## INSTALL POWERLINE AND DEV STUFF 
sudo pacman -S  ruby nodejs npm npm-check-updates gvim mlocate gkrellm

## INSTALL CHROME and ORANCHELO ICONS AND BREEZE CURSOR
yay -S google-chrome oranchelo-icon-theme-git xcursor-breeze

# NVM
mkdir $HOME/.nvm
[[ -x $(which git &>/dev/null) ]] && cd && git clone https://github.com/nvm-sh/nvm.git .nvm/.
[[ -d $HOME/.nvm ]] && cd ~/.nvm && source ./nvm.sh && cd


## DOTFILES
cp ~/.bashrc ~/.bashrc.orig
cp ~/.bash_profile ~/.bash_profile.orig
ln -sf ~/dotfiles/.bashrc .
ln -sf ~/dotfiles/.bash_profile .
ln -sf ~/dotfiles/.vimrc .


