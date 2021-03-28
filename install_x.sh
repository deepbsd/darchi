#!/usr/bin/env bash

## Use this script if you've not installed X et al previously.

install_x(){ return 0; }     # return 0 if you want to install X

video_driver='xf86-video-vmware'  # change if not using a virtual machine

declare -A display_mgr=( [dm]='lightdm' [service]='lightdm' )

## These are packages required for a working Xorg desktop (My preferences anyway)
basic_x=( xorg-server xorg-xinit mesa xorg-twm xterm gnome-terminal xfce4-terminal xorg-xclock firefox ${display_mgr[dm]} )

## These are your specific choices for fonts and wallpapers and X-related goodies
extra_x=( lightdm-gtk-greeter-settings lightdm-webkit-theme-litarvan )

themes_x=( breeze-gtk oxygen-gtk2 gtk-engine-murrine xcursor-themes adapta-gtk-theme arc-gtk-theme materia-gtk-theme xcursor-bluecurve xcursor-premium )

wallpapers_x=( archlinux-wallpaper deepin-community-wallpapers deepin-wallpapers elementary-wallpapers )

icons_x=( breeze-icons oxygen-icons elementary-icon-theme faenza-icon-theme gnome-icon-theme-extras arc-icon-theme mate-icon-theme papirus-icon-theme )

fonts_x=( adobe-source-code-pro-fonts cantarell-fonts gnu-free-fonts noto-fonts )

goodies=( alacritty terminator htop neofetch screenfetch powerline powerline-fonts powerline-vim )

## -----------  Some of these are included, but it's all up to you...
xfce_desktop=( xfce4 xfce4-goodies )

mate_desktop=( mate mate-extra )

i3gaps_desktop=( i3-gaps terminator alacritty dmenu feh rofi i3status i3blocks nitrogen i3status ttf-font-awesome ttf-ionicons )

extra_desktops=( "${xfce_desktop[@]}" "${mate_desktop[@]}" "${i3gaps_desktop[@]}" )

## Python3 should be installed by default
devel_stuff=( git nodejs npm npm-check-updates ruby )

printing_stuff=( system-config-printer foomatic-db foomatic-db-engine gutenprint cups cups-pdf cups-filters cups-pk-helper ghostscript gsfonts )

multimedia_stuff=( brasero sox cheese eog shotwell imagemagick sox cmus mpg123 alsa-utils cheese )


##########################################
######       FUNCTIONS       #############
##########################################
 
# All purpose error
error(){ echo "Error: $1" && exit 1; }

# FIND GRAPHICS CARD
find_card(){
    card=$(lspci | grep VGA | sed 's/^.*: //g')
    echo "You're using a $card" && echo
}


##########################################
######       INSTALL X       #############
##########################################

if $(install_x); then
    clear && echo "Installing X and X Extras and Video Driver. Type any key to continue"; read empty
    arch-chroot /mnt pacman -S "${basic_x[@]}"
    arch-chroot /mnt pacman -S "${themes_x[@]}"
    arch-chroot /mnt pacman -S "${wallpapers_x[@]}"
    arch-chroot /mnt pacman -S "${icons_x[@]}"
    arch-chroot /mnt pacman -S "${fonts_x[@]}"
    arch-chroot /mnt pacman -S "${goodies[@]}"
    arch-chroot /mnt pacman -S "${extra_x[@]}"
    your_card=$(find_card)
    echo "${your_card} and you're installing the $video_driver driver... (Type key to continue) "; read empty
    arch-chroot /mnt pacman -S "$video_driver"
    arch-chroot /mnt pacman -S "${extra_desktops[@]}"

    echo "Enabling display manager service..."
    arch-chroot /mnt systemctl enable ${display_mgr[service]}
    echo && echo "Your desktop and display manager should now be installed..."
    sleep 5
fi
