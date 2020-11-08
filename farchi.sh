#!/usr/bin/env bash

#####  GLOBAL VARIABLES  ######
HOSTNAME="effie3"
INSTALL_DEVICE=/dev/sda
EFI_DEVICE=/dev/sda1
## If you change the EFI_MTPT You must change
## it when making and mounting EFI dirs and also
## when installing grub. Just search for efi
EFI_MTPT=/mnt/boot/efi
ROOT_DEVICE=/dev/sda2
SWAP_DEVICE=/dev/sda3
HOME_DEVICE=/dev/sda4

# PARTITION SIZES
EFI_SIZE=512M
SWAP_SIZE=2G
ROOT_SIZE=12G
#HOME_SIZE=


TIME_ZONE="America/New_York"
LOCALE="en_US.UTF-8"
#$(ls /sys/firmware/efi/efivars &>/dev/null) && DISKTABLE='GPT' ) || DISKTABLE='MBR'
## Set this manually either to 'MBR' or 'GPT' for EFI systems
DISKTABLE=GPT
FILESYSTEM=ext4
DESKTOP=cinnamon
WIRELESSDRIVERS="broadcom-wl-dkms"
VIDEO_DRIVER="xf86-video-vmware"

## If you change display manager, be sure to change when
## we enable display manager service at end of script

## These are packages required for a working Xorg desktop
BASIC_X=( xorg-server xorg-xinit mesa xorg-twm xterm gnome-terminal xorg-xclock cinnamon nemo-fileroller lightdm xfce4-terminal firefox neofetch screenfetch lightdm-gtk-greeter)

## These are your specific choices for fonts and wallpapers and X-related goodies
EXTRA_X=( adobe-source-code-pro-fonts cantarell-fonts gnu-free-fonts noto-fonts breeze-gtk breeze-icons oxygen-gtk2 gtk-engine-murrine oxygen-icons xcursor-themes adapta-gtk-theme arc-gtk-theme elementary-icon-theme faenza-icon-theme gnome-icon-theme-extras arc-icon-theme lightdm-webkit-theme-litarvan mate-icon-theme materia-gtk-theme papirus-icon-theme xcursor-bluecurve xcursor-premium archlinux-wallpaper deepin-community-wallpapers deepin-wallpapers elementary-wallpapers )


##########################################
## SCRIPT STARTS HERE
##########################################

###  WELCOME
clear
echo -e "\n\n\nWelcome to the Fast ARCH Installer!"
sleep 4
clear && count=5
while true; do
    [[ "$count" -lt 0 ]] && break
    echo -e  "\e[1A\e[K Launching install in $count seconds"
    count=$(( count - 1 ))
    sleep 1
done

##  check if reflector update is done...
clear
echo "checking if reflector has finished updating mirrorlist yet..."
while true; do
    pgrep -x reflector &>/dev/null || break
    echo -n '.'
    sleep 2
done

## CHECK CONNECTION TO INTERNET
clear
echo "Testing internet connection..."
$(ping -c 3 archlinux.org &>/dev/null) || (echo "Not Connected to Network!!!" && exit 1)
echo "Good!  We're connected!!!" && sleep 3


## CHECK TIME AND DATE BEFORE INSTALLATION
timedatectl set-ntp true
echo && echo "Date/Time service Status is . . . "
timedatectl status
sleep 4

### PARTITION AND FORMAT AND MOUNT
clear && echo "Partitioning Installation Drive..." && sleep 3

sgdisk -Z "$IN_DEVICE"
sgdisk -n 1::+"$EFI_SIZE" -t 1:ef00 -c 1:EFI "$IN_DEVICE"
sgdisk -n 2::+"$ROOT_SIZE" -t 2:8300 -c 2:ROOT "$IN_DEVICE"
sgdisk -n 3::+"$SWAP_SIZE" -t 3:8200 -c 3:SWAP "$IN_DEVICE"
sgdisk -n 4 -c 4:HOME "$IN_DEVICE"

mkfs."$FILESYSTEM" "$ROOT_DEVICE"
mount "$ROOT_DEVICE" /mnt
if [[ "$EFI_DEVICE" != "" ]] ; then
    mkfs.fat -F32 "$EFI_DEVICE" 
    ### script assumes efi mounted at /mnt/boot/efi for now
    mkdir /mnt/boot
    mkdir /mnt/boot/efi 
    ( [[ -d "$EFI_MTPT" ]] && mount "$EFI_DEVICE" "$EFI_MTPT" ) || (echo "$EFI_MTPT does not exist!" && sleep 10 && exit 1)
fi
if [[ "$SWAP_DEVICE" != "" ]]; then mkswap "$SWAP_DEVICE" && swapon "$SWAP_DEVICE"; fi
if [[ "$HOME_DEVICE" != "" ]]; then
    mkfs."$FILESYSTEM" "$HOME_DEVICE"
    mkdir /mnt/home
    mount "$HOME_DEVICE" /mnt/home
fi

lsblk "$INSTALL_DEVICE"
echo "Type any key to continue..."; read empty

## INSTALL BASE SYSTEM
clear
echo && echo "Press any key to continue to install BASE SYSTEM..."; read empty
echo && echo "pacstrap system with base base-devel linux linux-headers linux-firmware vim..."
pacstrap /mnt base base-devel linux linux-headers linux-firmware vim 
echo && echo "Base system installed.  Press any key to continue..."; read empty

# GENERATE FSTAB
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# EDIT FSTAB IF NECESSARY
clear
echo && echo "Here's the new /etc/fstab..."; cat /mnt/etc/fstab
echo && echo "Edit /etc/fstab?"; read edit_fstab
[[ "$edit_fstab" =~ [yY] ]] && vim /mnt/etc/fstab


## SET UP TIMEZONE AND LOCALE
clear
echo && echo "setting timezone to $TIME_ZONE..."
#arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
arch-chroot /mnt ln -sf /usr/share/zoneinfo/"$TIME_ZONE" /etc/localtime
arch-chroot /mnt hwclock --systohc --utc
arch-chroot /mnt date
echo && echo "Here's the date info, hit any key to continue..."; read td_yn

## SET UP LOCALE
clear
echo && echo "setting locale to $LOCALE ..."
#arch-chroot /mnt sed -i "s/#en_US.UTF-8/en_US.UTF-8/g" /etc/locale.gen
arch-chroot /mnt sed -i "s/#$LOCALE/$LOCALE/g" /etc/locale.gen
arch-chroot /mnt locale-gen
#echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
echo "LANG=$LOCALE" > /mnt/etc/locale.conf
#export LANG=en_US.UTF-8
export LANG="$LOCALE"
cat /mnt/etc/locale.conf
echo && echo "Here's your /mnt/etc/locale.conf. Type any key to continue."; read loc_yn


## HOSTNAME
clear
echo && echo "Setting hostname..."; sleep 3
echo "$HOSTNAME" > /mnt/etc/hostname

cat > /mnt/etc/hosts <<HOSTS
127.0.0.1      localhost
::1            localhost
127.0.1.1      $HOSTNAME.localdomain     $HOSTNAME
HOSTS

echo && echo "/etc/hostname and /etc/hosts files configured..."
cat /mnt/etc/hostname 
cat /mnt/etc/hosts
echo && echo "Here are /etc/hostname and /etc/hosts. Type any key to continue "; read etchosts_yn

## SET PASSWD
clear
echo "Setting ROOT password..."
arch-chroot /mnt passwd

## INSTALLING MORE ESSENTIALS
clear
echo && echo "Enabling dhcpcd, sshd and NetworkManager services..." && echo
arch-chroot /mnt pacman -S git openssh networkmanager dhcpcd man-db man-pages
arch-chroot /mnt systemctl enable dhcpcd.service
arch-chroot /mnt systemctl enable sshd.service
arch-chroot /mnt systemctl enable NetworkManager.service

echo && echo "Press any key to continue..."; read empty

## ADD USER ACCT
clear
echo && echo "Adding sudo + user acct..."
sleep 2
arch-chroot /mnt pacman -S sudo bash-completion sshpass
arch-chroot /mnt sed -i 's/# %wheel/%wheel/g' /etc/sudoers
arch-chroot /mnt sed -i 's/%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/g' /etc/sudoers
echo && echo "Please provide a username: "; read sudo_user
echo && echo "Creating $sudo_user and adding $sudo_user to sudoers..."
arch-chroot /mnt useradd -m -G wheel "$sudo_user"
echo && echo "Password for $sudo_user?"
arch-chroot /mnt passwd "$sudo_user"

## INSTALL WIFI
clear && echo "Want to install $WIRELESSDRIVERS drivers?"; read wifi_yn
if [[ "$wifi_yn" =~ [yY] ]]; then
    #arch-chroot /mnt pacman -S broadcom-wl-dkms
    arch-chroot /mnt pacman -S "$WIRELESSDRIVERS"
    [[ "$?" -eq 0 ]] && echo "Wifi Driver successfully installed!"; sleep 5
fi


## INSTALL X AND DESKTOP
clear && echo "Installing X and X Extras and Video Driver. Type any key to continue"; read empty
arch-chroot /mnt pacman -S "${BASIC_X[@]}"
arch-chroot /mnt pacman -S "${EXTRA_X[@]}"
arch-chroot /mnt pacman -S "$VIDEO_DRIVER"
echo "Enabling display manager service..."
### CHANGE THIS IS YOU WANT A DIFFERENT DISPLAY MANAGER
### ALSO, ALTER BASIC_X and EXTRA_X ACCORDINGLY
arch-chroot /mnt systemctl enable lightdm.service
echo && echo "Your desktop and display manager should now be installed..."
sleep 5

## INSTALL GRUB
clear
echo "Installing grub..." && sleep 4
arch-chroot /mnt pacman -S grub 

if [[ "$DISKTABLE" =~ 'GPT' ]]; then
    arch-chroot /mnt pacman -S efibootmgr
    # /boot/efi should aready be mounted
    [[ ! -d /mnt/boot/efi ]] && echo "no /mnt/boot/efi directory!!!" && exit 1
    arch-chroot /mnt grub-install "$IN_DEVICE" --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi
    echo "efi grub bootloader installed..."
else
    arch-chroot /mnt grub-install "$INSTALL_DEVICE"
    echo "mbr bootloader installed..."
fi
echo "configuring /boot/grub/grub.cfg..."
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    
echo "System should now be installed and ready to boot!!!"
echo && echo "Type shutdown -h now and remove Installation Media and then reboot"
echo && echo



