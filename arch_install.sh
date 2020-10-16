#!/usr/bin/env bash

### Dave's Arch Installer -- execute from archiso 

# KEYBOARD: default console keymap is US so no need to change

# VERIFY BOOT MODE
efi_boot_mode(){
    ( $(ls /sys/firmware/efi/efivars &>/dev/null) && return 0 ) || return 1
}

# FIND GRAPHICS CARD
find_card(){
    card=$(lspci | grep VGA | sed 's/^.*: //g')
    echo "You're using a $card" && echo
}

# IF NOT CONNTECTED
not_connected(){
    clear
    echo "No network connection!!!  Perhaps your wifi card is not supported?"
    exit 1
}

####  START SCRIPT
DISKTABLE=''
clear
echo && echo "WELCOME TO DARCHI!  The easy Arch Install Script!"
echo && echo -n "waiting for reflector to update mirrors"
while true; do
    pgrep -x reflector &>/dev/null || break
    echo -n '.'
    sleep 3
done

# CONNTECTED??
clear
echo "Trying to ping google.com..."
$(ping -c 3 archlinux.org &>/dev/null) || (echo "Not Connected to Network!!!" && not_connected)


# UPDATE SYSTEM CLOCK
timedatectl set-ntp true
echo && echo "Date/Time service Status is . . . "
timedatectl status

# INSTALL TO WHAT DEVICE?
clear
echo "Available installation media: "  && echo
fdisk -l

echo && echo "Install to what device? (sda, nvme01, sdb, etc)" 
read device
if $(efi_boot_mode); then 
    echo && echo "Formatting with EFI/GPT"
    DISKTABLE='GPT'
else
    echo && echo "Formatting with BIOS/MBR"
    DISKTABLE='MBR'
fi

echo && echo "Recommend efi (512MB), root (100G), home (remaining), swap (32G) partitions..."
echo && echo "Continue to cfdisk? "; read answer
[[ "$answer" =~ [yY] ]] || exit 0

# PARTITION DISK
cfdisk /dev/"$device"

# SHOW RESULTS:
clear
echo && echo "Results of cfdisk: "
fdisk -l /dev/"$device"

echo && echo "EFI device name (leave empty if not EFI/GPT)?"; read efi_device
echo "Root device name?"; read root_device
echo "Swap device name?"; read swap_device
echo "Home device name?"; read home_device

echo && echo "Continue?"; read more

# FORMAT AND MOUNT PARTITIONS 
echo && echo "Continue to formatting and mounting partitions?"; read format_mount
[[ "$format_mount" =~ [yY] ]] || exit 0

clear
echo "formatting and mounting partitions..."
# don't recreate an existing efi partition!
if [[ "$DISKTABLE" =~ 'GPT' && -n "$efi_device" && ! -d "/dev/$efi_device" ]]; then
    mkfs.fat -F32 /dev/"$efi_device"
    sleep 3
    mkdir /mnt/boot && mkdir /mnt/boot/efi
    sleep 3
    mount /dev/"$efi_device" /mnt/boot/efi
    sleep 3
    echo 'mounting new EFI partition...'
    echo && echo "Press any key to continue..."; read nuttin
elif [[ "$DISKTABLE" =~ 'GPT' && -d /dev/"$efi_device" ]]; then
    mkdir /mnt/boot && mkdir /mnt/boot/efi
    mount /dev/"$efi_device" /mnt/boot/efi
    echo 'mounting existing EFI partition...'
    echo && echo "Press any key to continue..."; read nuttin
else
    echo "Not mounting an EFI device..."
    echo && echo "Press any key to continue..."; read nuttin
fi

mkfs.ext4 /dev/"$root_device" && mount /dev/"$root_device" /mnt
mkswap /dev/"$swap_device"
swapon /dev/"$swap_device"

if [[ -n "$home_device" ]]; then
    [[ ! -d /mnt/home ]] && mkdir /mnt/home
    mkfs.ext4 /dev/"$home_device" && mount /dev/"$home_device" /mnt/home
fi

# SHOW RESULTS AGAIN
echo "Latest changes to disk..."
lsblk -f
if [[ -d /mnt/boot/efi ]]; then
    echo && echo "EFI part is mounted!"
else
    echo && echo "EFI part is NOT mounted!"
    exit 1
fi

echo "Press any key to continue to install BASE SYSTEM..."; read empty

## UPDATE MIRRORLIST  # happens automatically now in archiso

# INSTALL ESSENTIAL PACKAGES
echo && echo "pacstrap system with base base-devel linux linux-firmware vim..."
pacstrap /mnt base base-devel linux linux-headers linux-firmware vim 

## I have numerous Broadcom BCM4360 chipset PCI cards...
## Might need to install broadcom-wl (or broadcom-wl-dkms) for wifi card
## if so, rmmod b43, rmmod ssb, modprobe wl
## if this doesn't work, run depmod -a

echo && echo "Base system installed.  Press any key to continue..."; read empty

# CONFIGURE FILESYSTEMS
clear
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# EDIT FSTAB IF NECESSARY
clear
echo && echo "Here's /etc/fstab..."; cat /mnt/etc/fstab
echo && echo "Press any key to continue..."; read empty
echo && echo "Edit /etc/fstab?"; read edit_fstab
[[ "$edit_fstab" =~ [yY] ]] && vim /mnt/etc/fstab

# CHROOT
clear
echo && echo "Starting CHROOT operations..."
echo && echo "Continue on to setting timezone?"; read tz_yn
[[ "$tz_yn" =~ [yY] ]] || exit 0

# TIMEZONE
echo && echo "setting timezone to America/New_York..."
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
arch-chroot /mnt hwclock --systohc --utc
arch-chroot /mnt date
echo && echo "Does date look correct?"; read td_yn
[[ "$td_yn" =~ [yY] ]] || exit 0

# LOCALE
echo && echo "setting locale to en_US.UTF-8..."
arch-chroot /mnt sed -i 's/#en_US.UTF-8/en_US.UTF-8/g' /etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
export LANG=en_US.UTF-8
cat /mnt/etc/locale.conf
echo && echo "Does locale setting look correct?"; read loc_yn
[[ "$loc_yn" =~ [yY] ]] || exit 0

# HOSTNAME
clear
echo && echo "What is the hostname?"; read namevar
echo "$namevar" > /mnt/etc/hostname

cat > /mnt/etc/hosts <<HOSTS
127.0.0.1      localhost
::1            localhost
127.0.1.1      $namevar.localdomain     $namevar
HOSTS

echo && echo "/etc/hostname and /etc/hosts files configured..."
cat /mnt/etc/hostname 
cat /mnt/etc/hosts
echo && echo "Do /etc/hostname and /etc/hosts look correct?"; read etchosts_yn
[[ "$etchosts_yn" =~ [yY] ]] || exit 0
echo && echo "Continue to set ROOT password and enable sshd and NetworkManager?" 
read myanswer
[[ "$myanswer" =~ [yY] ]] || exit 0


# SET ROOT PASSWORD
clear
echo "Setting ROOT password..."
arch-chroot /mnt passwd

# MORE ESSENTIAL SOFTWARE
echo && echo "Enabling dhcpcd, sshd and NetworkManager services..."
echo
arch-chroot /mnt pacman -S git openssh networkmanager dhcpcd
arch-chroot /mnt systemctl enable dhcpcd.service
arch-chroot /mnt systemctl enable sshd.service
arch-chroot /mnt systemctl enable NetworkManager.service


echo && echo "Press any key to continue..."; read empty

# ADD A USER
clear
echo "Continue to add a user?"; read myanswer
[[ "$myanswer" =~ [yY] ]] || exit 0

arch-chroot /mnt pacman -S sudo bash-completion man-pages man-db
arch-chroot /mnt sed -i 's/# %wheel/%wheel/g' /etc/sudoers
arch-chroot /mnt sed -i 's/%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/g' /etc/sudoers
echo && echo "Please provide a username: "; read sudo_user
echo && echo "Creating $sudo_user and adding $sudo_user to sudoers..."
arch-chroot /mnt useradd -m -G wheel "$sudo_user"
echo && echo "Password for $sudo_user?"
arch-chroot /mnt passwd "$sudo_user"

echo && echo "Continue to install GRUB?"; read myanswer
[[ "$myanswer" =~ [yY] ]] || exit 0


# INSTALL BOOTLOADER
clear
arch-chroot /mnt pacman -S grub 

if $(efi_boot_mode); then
    arch-chroot /mnt pacman -S efibootmgr
    # /boot/efi should aready be mounted
    [[ ! -d /mnt/boot/efi ]] && echo "no /mnt/boot/efi directory!!!" && exit 1
    arch-chroot /mnt grub-install /dev/sda --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi
    echo "efi grub bootloader installed..."
else
    arch-chroot /mnt grub-install /dev/"$device"
    echo "mbr bootloader installed..."
fi

arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
echo "/boot/grub/grub.cfg configured..."
    
echo "Press any key to continue..."; read empty

echo "Would you like to install Xorg and desktop? (y or n)"; read xorg_yes
[[ "$xorg_yes" =~ [yY] ]] || exit 0

# XORG AND DESKTOP
clear
echo "Installing Xorg and Desktop..."

basicx=( xorg-server xorg-xinit mesa xorg-twm xterm gonome-terminal xorg-xclock cinnamon nemo-fileroller lightdm xfce4-terminal firefox neofetch screenfetch )

pacman -S "${basicx[@]}"

extrax=( adobe-source-code-pro-fonts cantarell-fonts gnu-free-fonts noto-fonts breeze-gtk breeze-icons oxygen-gtk2 oxygen-icons xcursor-themes adapta-gtk-theme arc-gtk-theme elementary-icon-theme faenza-icon-theme gnome-icon-theme-extras arc-icon-theme lightdm-webkit-theme-litarvan mate-icon-theme materia-gtk-theme moka-icon-theme papirus-icon-theme xcursor-bluecurve xcursor-premium archlinux-wallpaper deepin-community-wallpapers deepin-wallpapers elementary-wallpapers )

## Also, install fonts and icon and cursor themes
pacman -S "${extrax[@]}"

# INSTALL DRIVER FOR YOUR GRAPHICS CARD
find_card
arch-chroot /mnt pacman -Ss | grep 'xf86-video' | less
echo "Which driver is yours?"; read driver
arch-chroot /mnt pacman -S "$driver"

echo "Enabling lightdm service..."
arch-chroot /mnt systemctl enable lightdm.service


echo "Type 'shutdown -r now' to reboot..."
# END OF SCRIPT

