#!/usr/bin/env bash

### Dave's Arch Installer -- execute from archiso 

# KEYBOARD: default console keymap is US so no need to change

# VERIFY BOOT MODE
efi_boot_mode(){
    $(ls /sys/firmware/efi/efivars) && return 0  || return 1
}

# FIND GRAPHICS CARD
find_card(){
    card=$(lspci | grep VGA | sed 's/^.*: //g')
    echo "$card"
}

install_gr_drv(){
    pacman -S "$1"
}

# CONNTECTED??
$(ping -c 3 archlinux.org &>/dev/null) || (echo "Not Connected to Network!!!" && exit 1)


# UPDATE SYSTEM CLOCK
timedatectl set-ntp true
echo "Date/Time service Status is . . . "
timedatectl status

echo "waiting for timedatectl status to complete..."
sleep 6

# INSTALL TO WHAT DEVICE?
echo "Available installation media: "
fdisk -l

echo "Install to what device? (sda, nvme01, sdb, etc)" 
read device
if $(efi_boot_mode); then 
    echo "Formatting with EFI/GPT"
else
    echo "Formatting with BIOS/MBR"
fi

echo "Recommend efi (500MB), root (100G), home (remaining), swap (32G) partitions..."
echo "Continue to cfdisk? "; read answer
[[ "$answer" =~ [yY] ]] || exit 0

# PARTITION DISK
cfdisk /dev/"$device"

# SHOW RESULTS:
echo "Results of cfdisk: "
fdisk -l /dev/"$device"

echo "EFI device name (leave empty if not EFI/GPT)?"; read efi_device
echo "Root device name?"; read root_device
echo "Swap device name?"; read swap_device
echo "Home device name?"; read home_device


# FORMAT AND MOUNT PARTITIONS 
echo "Continue to formatting and mounting partitions?"; read format_mount
[[ "$format_mount" =~ [yY] ]] || exit 0
echo "formatting and mounting partitions..."
# don't recreate an existing efi partition!
[[ -n "$efi_device" && ! -d "/dev/$efi_device" ]] && mkfs.fat -F32 /dev/"$efi_device" && mkdir /boot/efi && mount /dev/"$efi_device" /boot/efi
mkfs.ext4 /dev/"$root_device" && mount /dev/"$root_device" /mnt
mkswap /dev/"$swap_device"
swapon /dev/"$swap_device"
[[ ! -d /mnt/home ]] && mkdir /mnt/home
mkfs.ext4 /dev/"$home_device" && mount /dev/"$home_device" /mnt/home

# SHOW RESULTS AGAIN
echo "Latest changes to disk..."
lsblk -f

echo "Press any key to continue..."; read empty

# UPDATE MIRRORLIST
echo "Next, update mirrorlist.  Continue? "; read yes_no
[[ "$yes_no" =~ [yY] ]] || exit 0

echo "Updating mirrorlist..."
#pacman -Sy --noconfirm reflector   # reflector installed already
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig
reflector --country US --latest 25 --age 24 --protocol https --completion-percent 100 --sort rate --save /etc/pacman.d/mirrorlist

# INSTALL ESSENTIAL PACKAGES
echo "pacstrap system with base base-devel linux linux-firmware vim..."
pacstrap /mnt base base-devel linux linux-headers linux-firmware vim 

## I have numerous Broadcom BCM4360 chipset PCI cards...
## Might need to install broadcom-wl (or broadcom-wl-dkms) for wifi card
## if so, rmmod b43, rmmod ssb, modprobe wl
## if this doesn't work, run depmod -a

# CONFIGURE FILESYSTEMS
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# EDIT FSTAB IF NECESSARY
echo "Here's /etc/fstab..."; cat /mnt/etc/fstab
echo "Edit /etc/fstab?"; read edit_fstab
[[ "$edit_fstab" =~ [yY] ]] && vim /mnt/etc/fstab

# CHROOT
echo "Starting CHROOT operations..."
#arch-chroot /mnt
echo "Continue on to setting timezone?"; read tz_yn
[[ "$tz_yn" =~ [yY] ]] || exit 0

# TIMEZONE
echo "setting timezone to America/New_York..."
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
arch-chroot /mnt hwclock --systohc --utc
arch-chroot /mnt date
echo "Does date look correct?"; read td_yn
[[ "$td_yn" =~ [yY] ]] || exit 0

# LOCALE
echo "setting locale to en_US.UTF-8..."
arch-chroot /mnt sed -i 's/#en_US.UTF-8/en_US.UTF-8/g' /etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
export LANG=en_US.UTF-8
cat /mnt/etc/locale.conf
echo "Does locale setting look correct?"; read loc_yn
[[ "$loc_yn" =~ [yY] ]] || exit 0

# HOSTNAME
echo "What is the hostname?"; read namevar
echo "$namevar" > /mnt/etc/hostname

cat > /mnt/etc/hosts <<HOSTS
127.0.0.1      localhost
::1            localhost
127.0.1.1      $namevar.localdomain     $namevar
HOSTS

echo "/etc/hostname and /etc/hosts files configured..."
cat /mnt/etc/hostname 
cat /mnt/etc/hosts
echo "Do /etc/hostname and /etc/hosts look correct?"; read etchosts_yn
[[ "$etchosts_yn" =~ [yY] ]] || exit 0
echo "Continue to set ROOT password and enable sshd and NetworkManager?" 
read myanswer
[[ "$myanswer" =~ [yY] ]] || exit 0


# SET ROOT PASSWORD
echo "Setting ROOT password..."
arch-chroot /mnt passwd

# MORE ESSENTIAL SOFTWARE
echo "Enabling sshd and NetworkManager services..."
arch-chroot /mnt pacman -S git openssh networkmanager dhcpcd
arch-chroot /mnt systemctl enable dhcpcd.service
arch-chroot /mnt systemctl enable sshd.service
arch-chroot /mnt systemctl enable NetworkManager.service


# ADD A USER
echo "Continue to add a user?"; read myanswer
[[ "$myanswer" =~ [yY] ]] || exit 0

arch-chroot /mnt pacman -S sudo bash-completion
arch-chroot /mnt sed -i 's/# %wheel/%wheel/g' /etc/sudoers
arch-chroot /mnt sed -i 's/%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/g' /etc/sudoers
echo "Please add a username (provide username): "; read sudo_user
echo "Creating $sudo_user and adding $sudo_user to sudoers..."
arch-chroot /mnt useradd -m -G wheel "$sudo_user"
echo "Password for $sudo_user?"
arch-chroot /mnt passwd "$sudo_user"

echo "Continue to install GRUB?"; read myanswer
[[ "$myanswer" =~ [yY] ]] || exit 0


# INSTALL BOOTLOADER
arch-chroot /mnt pacman -S grub 

if $(efi_boot_mode); then
    arch-chroot /mnt pacman -S efibootmgr
    # /boot/efi should aready be mounted
    #mount /dev/"$efi_device" /boot/efi
    arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi
    echo "efi grub bootloader installed..."
else
    arch-chroot /mnt grub-install /dev/"$device"
    echo "mbr bootloader installed..."
fi

arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
echo "/boot/grub/grub.cfg configured..."
    
echo "Would you like to install Xorg and desktop? (y or n)"; read xorg_yes
[[ "$xorg_yes" =~ [yY] ]] || exit 0

# XORG AND DESKTOP
echo "Installing Xorg and Desktop..."
arch-chroot /mnt pacman -S xorg-server xorg-xinit mesa xorg-twm xterm gnome-terminal xorg-xclock cinnamon nemo-fileroller lightdm xfce4-terminal

arch-chroot /mnt pacman -S lightdm-gtk-greeter firefox screenfetch neofetch
## Also, install fonts and icon and cursor themes
arch-chroot /mnt pacman -S adobe-source-code-pro-fonts cantarell-fonts gnu-free-fonts noto-fonts
arch-chroot /mnt pacman -S breeze-gtk breeze-icons oxygen-gtk2 oxygen-icons xcursor-themes
arch-chroot /mnt pacman -S adapta-gtk-theme arc-gtk-theme arc-icon-theme
arch-chroot /mnt pacman -S elementary-icon-theme faenza-icon-theme gnome-icon-theme-extras
arch-chroot /mnt pacman -S lightdm-webkit-theme-litarvan mate-icon-theme materia-gtk-theme
arch-chroot /mnt pacman -S moka-icon-theme papirus-icon-theme xcursor-bluecurve xcursor-premium archlinux-wallpaper deepin-community-wallpapers deepin-wallpapers elementary-wallpapers

# INSTALL DRIVER FOR YOUR GRAPHICS CARD
find_card
arch-chroot /mnt pacman -Ss | grep 'xf86-video' | less
echo "Which driver is yours?"; read driver
arch-chroot /mnt pacman -S "$driver"

echo "Enabling lightdm service..."
arch-chroot /mnt systemctl enable lightdm.service


echo "Type 'shutdown -r now' to reboot..."
# END OF SCRIPT

