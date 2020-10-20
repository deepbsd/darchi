#!/usr/bin/env bash

### Dave's Arch Installer -- execute from archiso 

# KEYBOARD: default console keymap is US so no need to change

### GLOBAL VARIABLES
DISKTABLE=''
IN_DRIVE=''
EFI_SLICE=''
ROOT_SLICE=''
HOME_SLICE=''
SWAP_SLICE=''

###########  FUNCTIONS ###################

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
    echo "Is your network cable plugged in?"
    exit 1
}

# CONNTECTED??
check_connect(){
    clear
    echo "Trying to ping google.com..."
    $(ping -c 3 archlinux.org &>/dev/null) || (echo "Not Connected to Network!!!" && not_connected)
    echo "Good!  We're connected!!!" && sleep 4
}

# UPDATE SYSTEM CLOCK
time_date(){
    timedatectl set-ntp true
    echo && echo "Date/Time service Status is . . . "
    timedatectl status
    sleep 4
}

# MOUNT PARTION
mount_part(){
    device=$1; mt_pt=$2
    [[ ! -d /mnt/boot ]] && mkdir /mnt/boot
    [[ ! -d /mnt/boot/efi ]] && mkdir /mnt/boot/efi
    [[ ! -d "$mt_pt" ]] && mkdir "$mt_pt" 
    echo "Device: $device mount point: $mt_pt"
    mount "$device" "$mt_pt"
    if [[ "$?" -eq 0 ]]; then
        echo "$device mounted on $mt_pt ..."
    else
        echo "Error!!  $mt_pt not mounted!"
        exit 1
    fi
    return 0
}

# FORMAT DEVICE
format_disk(){
    device=$1; slice=$2
    clear
    echo "Formatting $device with $slice. . ."
    sleep 3
    case $slice in 
        efi ) mkfs.fat -F32 "$device"
            mount_part "$device" /mnt/boot/efi
            ;;
        home  ) mkfs.ext4 "$device"
            mount_part "$device" /mnt/home
            ;;
        root  ) mkfs.ext4 "$device"
            mount_part "$device" /mnt
            ;;
        swap  ) mkswap "$device"
                swapon "$device"
                echo && echo "Swap space should be turned on now..."
            ;;
        * ) echo "Cannot make that type of device" && exit 1 ;;
    esac
}

# PARTITION DISK
part_disk(){
    device=$1
    echo && echo "Recommend efi (512MB), root (100G), home (remaining), swap (32G) partitions..."
    echo && echo "Continue to cfdisk? "; read answer
    [[ "$answer" =~ [yY] ]] || exit 0
    IN_DEVICE="/dev/$device"

    cfdisk "$IN_DEVICE"

    # SHOW RESULTS:
    clear
    echo && echo "Results of cfdisk: "
    fdisk -l "$IN_DEVICE"
    lsblk -f "$IN_DEVICE"

    echo "Root device name?"; read root_device
    ROOT_SLICE="/dev/$root_device"
    echo "Formatting $ROOT_SLICE" && sleep 2 
    [[ -n "$root_device" ]] && format_disk "$ROOT_SLICE" root

    lsblk -f "$IN_DEVICE" && echo "EFI device name (leave empty if not EFI/GPT)?"; read efi_device
    EFI_SLICE="/dev/$efi_device"
    echo "Formatting $EFI_SLICE" && sleep 2
    [[ -n "$efi_device" ]] && format_disk "$EFI_SLICE" efi

    lsblk -f "$IN_DEVICE" && echo "Swap device name? (leave empty if no swap device)"; read swap_device
    SWAP_SLICE="/dev/$swap_device"
    echo "Formatting $SWAP_SLICE" && sleep 2
    [[ -n "$swap_device" ]] && format_disk "$SWAP_SLICE" swap

    lsblk -f "$IN_DEVICE" && echo "Home device name? (leave empty if no swap device)"; read home_device
    HOME_SLICE="/dev/$home_device"
    echo "Formatting $HOME_SLICE" && sleep 2
    [[ -n "$home_device" ]] && format_disk "$HOME_SLICE" home

    lsblk -f "$IN_DEVICE"
    echo && echo "Disks should be partioned and mounted.  Continue?"; read more
    [[ ! "$more" =~ [yY] ]] && exit 1
}

# INSTALL TO WHAT DEVICE?
get_install_device(){
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

    part_disk "$device"
}

# INSTALL ESSENTIAL PACKAGES
install_base(){
    clear
    echo && echo "Press any key to continue to install BASE SYSTEM..."; read empty
    echo && echo "pacstrap system with base base-devel linux linux-firmware vim..."
    pacstrap /mnt base base-devel linux linux-headers linux-firmware vim 
    echo && echo "Base system installed.  Press any key to continue..."; read empty

    # For future consideration...

    ## I have numerous Broadcom BCM4360 chipset PCI cards...
    ## Might need to install broadcom-wl (or broadcom-wl-dkms) for wifi card
    ## if so, rmmod b43, rmmod ssb, modprobe wl
    ## if this doesn't work, run depmod -a
}

# GENERATE FSTAB
gen_fstab(){
    clear
    echo "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
    sleep 5

    # EDIT FSTAB IF NECESSARY
    clear
    echo && echo "Here's the new /etc/fstab..."; cat /mnt/etc/fstab
    echo && echo "Edit /etc/fstab?"; read edit_fstab
    [[ "$edit_fstab" =~ [yY] ]] && vim /mnt/etc/fstab
}

# TIMEZONE
set_tz(){
    clear
    echo && echo "Continue on to setting timezone with CHROOT?"; read tz_yn
    [[ "$tz_yn" =~ [yY] ]] || exit 0

    echo && echo "setting timezone to America/New_York..."
    arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
    arch-chroot /mnt hwclock --systohc --utc
    arch-chroot /mnt date
    echo && echo "Does date look correct?"; read td_yn
    [[ "$td_yn" =~ [yY] ]] || exit 0

}

# LOCALE
set_locale(){
    clear
    echo && echo "setting locale to en_US.UTF-8..."
    arch-chroot /mnt sed -i 's/#en_US.UTF-8/en_US.UTF-8/g' /etc/locale.gen
    arch-chroot /mnt locale-gen
    echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
    export LANG=en_US.UTF-8
    cat /mnt/etc/locale.conf
    echo && echo "Does locale setting look correct?"; read loc_yn
    [[ "$loc_yn" =~ [yY] ]] || exit 0
}

# HOSTNAME
set_hostname(){
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
}

# SOME MORE ESSENTIAL NETWORK STUFF
install_essential(){
    clear
    echo && echo "Enabling dhcpcd, sshd and NetworkManager services..."
    echo
    arch-chroot /mnt pacman -S git openssh networkmanager dhcpcd man-db man-pages
    arch-chroot /mnt systemctl enable dhcpcd.service
    arch-chroot /mnt systemctl enable sshd.service
    arch-chroot /mnt systemctl enable NetworkManager.service


    echo && echo "Press any key to continue..."; read empty
}

# ADD A USER ACCT
add_user_acct(){
    clear
    echo && echo "Adding sudo + user acct..."
    sleep 4
    arch-chroot /mnt pacman -S sudo bash-completion
    arch-chroot /mnt sed -i 's/# %wheel/%wheel/g' /etc/sudoers
    arch-chroot /mnt sed -i 's/%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/g' /etc/sudoers
    echo && echo "Please provide a username: "; read sudo_user
    echo && echo "Creating $sudo_user and adding $sudo_user to sudoers..."
    arch-chroot /mnt useradd -m -G wheel "$sudo_user"
    echo && echo "Password for $sudo_user?"
    arch-chroot /mnt passwd "$sudo_user"
}

# INSTALL BOOTLOADER
install_grub(){
    clear
    echo && echo "Continue to install GRUB?"; read myanswer
    [[ "$myanswer" =~ [yY] ]] || exit 0

    arch-chroot /mnt pacman -S grub 

    if $(efi_boot_mode); then
        arch-chroot /mnt pacman -S efibootmgr
        # /boot/efi should aready be mounted
        [[ ! -d /mnt/boot/efi ]] && echo "no /mnt/boot/efi directory!!!" && exit 1
        [[ -n "$IN_DEVICE" ]] && echo "Install device global variable undefined!" && exit 1
        arch-chroot /mnt grub-install "$IN_DEVICE" --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi
        echo "efi grub bootloader installed..."
    else
        arch-chroot /mnt grub-install "$IN_DEVICE"
        echo "mbr bootloader installed..."
    fi

    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    echo "/boot/grub/grub.cfg configured..."
        
    echo "Press any key to continue..."; read empty
}

# INSTALL XORG AND DESKTOP
install_desktop(){
    clear
    echo && echo "Would you like to install Xorg and desktop? (y or n)"; read xorg_yes
    [[ "$xorg_yes" =~ [yY] ]] || exit 0

    # XORG AND DESKTOP
    clear
    echo "Installing Xorg and Desktop..."

    basicx=( xorg-server xorg-xinit mesa xorg-twm xterm gnome-terminal xorg-xclock cinnamon nemo-fileroller lightdm xfce4-terminal firefox neofetch screenfetch lightdm-gtk-greeter)

    arch-chroot /mnt pacman -S "${basicx[@]}"

    extra_x=( adobe-source-code-pro-fonts cantarell-fonts gnu-free-fonts noto-fonts breeze-gtk breeze-icons oxygen-gtk2 gtk-engine-murrine oxygen-icons xcursor-themes adapta-gtk-theme arc-gtk-theme elementary-icon-theme faenza-icon-theme gnome-icon-theme-extras arc-icon-theme lightdm-webkit-theme-litarvan mate-icon-theme materia-gtk-theme papirus-icon-theme xcursor-bluecurve xcursor-premium archlinux-wallpaper deepin-community-wallpapers deepin-wallpapers elementary-wallpapers )

    ## Also, install fonts and icon and cursor themes
    arch-chroot /mnt pacman -S "${extra_x[@]}"

    # INSTALL DRIVER FOR YOUR GRAPHICS CARD
    find_card
    arch-chroot /mnt pacman -Ss | grep 'xf86-video' | more
    echo "Which driver is yours?"; read driver
    arch-chroot /mnt pacman -S "$driver"

    echo "Enabling lightdm service..."
    arch-chroot /mnt systemctl enable lightdm.service
    echo && echo "Cinnamon and lightdm should now be installed..."
    sleep 5
}
#############################################################
###################  START SCRIPT
#############################################################
start(){
    clear
    echo && echo "WELCOME TO DARCHI!  The easy Arch Install Script!"
    sleep 4
    echo && echo -n "waiting for reflector to update mirrorlist"
    while true; do
        pgrep -x reflector &>/dev/null || break
        echo -n '.'
        sleep 3
    done

    check_connect
    time_date
    get_install_device  # this func calls partition func
    #update_mirrorlist # done already in archiso img
    install_base
    gen_fstab
    set_tz
    set_locale
    set_hostname
    # SET ROOT PASSWORD
    echo "Setting ROOT password..."
    arch-chroot /mnt passwd
    install_essential
    add_user_acct
    install_grub
    install_desktop
    echo "Type 'shutdown -r now' to reboot..."
}

start

