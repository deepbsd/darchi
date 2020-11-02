#!/usr/bin/env bash

### Dave's Arch Installer -- execute from archiso 

# KEYBOARD: default console keymap is US so no need to change

### GLOBAL VARIABLES
##  ** Do NOT edit these! They are updated programmatically **
DISKTABLE=''
IN_DRIVE=''
EFI_SLICE=''
ROOT_SLICE=''
HOME_SLICE=''
SWAP_SLICE=''

# You can edit this if you want
TIMEZONE='America/New_York'
LOCALE="en_US.UTF-8"

###########  SOFTWARE SETS ###################

base_system=( base base-devel linux linux-headers linux-firmware vim sudo bash-completion )

base_essentials=(pacman-contrib dkms openssh networkmanager dhcpcd man-db man-pages)

display_mgr=(lightdm)

my_services=( dhcpcd sshd NetworkManager lightdm )

basic_x=( xorg-server xorg-xinit mesa xkill xorg-twm xterm gnome-terminal xorg-xclock xfce4-terminal firefox neofetch screenfetch lightdm-gtk-greeter )

extra_x=( gkrellm powerline powerline-fonts powerline-vim adobe-source-code-pro-fonts cantarell-fonts gnu-free-fonts noto-fonts breeze-gtk breeze-icons oxygen-gtk2 gtk-engine-murrine oxygen-icons xcursor-themes adapta-gtk-theme arc-gtk-theme elementary-icon-theme faenza-icon-theme gnome-icon-theme-extras arc-icon-theme lightdm-webkit-theme-litarvan mate-icon-theme materia-gtk-theme papirus-icon-theme xcursor-bluecurve xcursor-premium archlinux-wallpaper deepin-community-wallpapers deepin-wallpapers elementary-wallpapers )

graphics_driver=(xf86-video-vmware)

wifi_drivers=(broadcom-wl-dkms)

cinnamon_desktop=( cinnamon nemo-fileroller )

#####  Include in 'all_extras' array if desired
xfce_desktop=( xfce4 xfce4-goodies )

mate_desktop=( mate mate-extra )

i3gaps_desktop=( i3-gaps dmenu feh rofi i3status i3bar i3blocks
    nitrogen i3status ttf-font-awesome
    ttf-ionicons ttf-font-icons )

## Python3 should be installed by default
devel_stuff=( git base-devel nodejs ruby )

printing_stuff=( system-config-printer foomatic-db foomatic-db-engine gutenprint cups cups-pdf cups-filters cups-pk-helper ghostscript gsfonts )

multimedia_stuff=( eog shotwell imagemagick sox cmus mpg123 alsa-utils
    cheese brasaero )

##  fonts_themes=()    #  in case I want to break these out from extra_x

all_extras=("${i3gaps_desktop[@]} ${devel_stuff[@]} ${printing_stuff[@]}
    ${multimedia_stuff[@]}" )

##########################################
###########  FUNCTIONS ###################
##########################################

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

# ARE WE CONNTECTED??
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
    $(efi_boot_mode) && ! [ -d /mnt/boot/efi ] && mkdir /mnt/boot/efi
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
    # only do efi slice if efi_boot_mode return 0; else return 0
    ##  This is a problem!!  The efi slice is not getting formatted or mounted!!!
    [[ "$slice" =~ 'efi' && ! "$DISKTABLE" =~ 'GPT' ]] && return 0
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
    IN_DEVICE="/dev/$device"
    echo && echo "Recommend efi (512MB), root (100G), home (remaining), swap (32G) partitions..."
    #echo && echo "Continue to cfdisk? "; read answer
    echo && echo "Continue to sgdisk? "; read answer
    #[[ "$answer" =~ [yY] ]] && cfdisk "$IN_DEVICE"
    [[ "$answer" =~ [yY] ]] && echo "paritioning with sgdisk..."
    sgdisk -Z "$IN_DEVICE"
    sgdisk -n 1::+512M -t 1:ef00 -c 1:EFI "$IN_DEVICE"
    sgdisk -n 2::+13G -t 2:8300 -c 2:ROOT "$IN_DEVICE"
    sgdisk -n 3::+2G -t 3:8200 -c 3:SWAP "$IN_DEVICE"
    sgdisk -n 4 -c 4:HOME "$IN_DEVICE"

    # SHOW RESULTS:
    clear
    echo && echo "Status of disk device: "
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
    echo && echo "pacstrap system with base base-devel linux linux-headers dkms linux-firmware vim..."
    #pacstrap /mnt base base-devel linux linux-headers dkms linux-firmware vim 
    pacstrap /mnt "${base_system[@]}"
    echo && echo "Base system installed.  Press any key to continue..."; read empty
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
    #echo && echo "Continue on to setting timezone with CHROOT?"; read tz_yn
    #[[ "$tz_yn" =~ [yY] ]] || exit 0

    echo && echo "setting timezone to $TIMEZONE..."
    #arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
    arch-chroot /mnt ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
    arch-chroot /mnt hwclock --systohc --utc
    arch-chroot /mnt date
    echo && echo "Does date look correct?"; read td_yn
    [[ "$td_yn" =~ [yY] ]] || exit 0

}

# LOCALE
set_locale(){
    clear
    echo && echo "setting locale to en_US.UTF-8..."
    #arch-chroot /mnt sed -i 's/#en_US.UTF-8/en_US.UTF-8/g' /etc/locale.gen
    arch-chroot /mnt sed -i "s/#$LOCALE/$LOCALE/g" /etc/locale.gen
    arch-chroot /mnt locale-gen
    #echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
    echo "LANG=$LOCALE" > /mnt/etc/locale.conf
    #export LANG=en_US.UTF-8
    export LANG="$LOCALE"
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
    #arch-chroot /mnt pacman -S git openssh networkmanager dhcpcd man-db man-pages
    #arch-chroot /mnt systemctl enable dhcpcd.service
    #arch-chroot /mnt systemctl enable sshd.service
    #arch-chroot /mnt systemctl enable NetworkManager.service

    arch-chroot /mnt pacman -S 


    echo && echo "Press any key to continue..."; read empty
}

# ADD A USER ACCT
add_user_acct(){
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
}

# THIS IS IF YOU HAVE TO RESTART THE SCRIPT AFTER PARTITIONING
set_variables(){
    clear && echo "Installation device?  (sda, nvme0n, sdb, etc)"; read inst_device
    echo && echo "Install root to? (sda2? nvme0np2?)"; read root_slice
    echo && echo "Install swap to? (leave emtpy if no swap part)"; read swap_slice
    echo && echo "Install EFI to? (leave empty if MBR disk)"; read efi_slice
    echo && echo "Install HOME slice to?  (leave empty if you don't want a separate home partition)"; read home_slice

    if $(efi_boot_mode) ; then
        DISKTABLE="GPT"
    else
        DISKTABLE="MBR"
    fi
    IN_DEVICE="/dev/$inst_device"
    EFI_SLICE="/dev/$efi_slice"
    SWAP_SLICE="/dev/$swap_slice"
    ROOT_SLICE="/dev/$root_slice"
    HOME_SLICE="/dev/$home_slice"
}


# INSTALL BOOTLOADER
install_grub(){
    clear
    echo "Installing grub..."
    arch-chroot /mnt pacman -S grub os-prober

    if $(efi_boot_mode); then
        arch-chroot /mnt pacman -S efibootmgr
        # /boot/efi should aready be mounted
        [[ ! -d /mnt/boot/efi ]] && echo "no /mnt/boot/efi directory!!!" && exit 1
        #[[ -n "$IN_DEVICE" ]] || echo "Install device global variable undefined!" && exit 1
        arch-chroot /mnt grub-install "$IN_DEVICE" --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi
        echo "efi grub bootloader installed..."
    else
        arch-chroot /mnt grub-install "$IN_DEVICE"
        echo "mbr bootloader installed..."
    fi

    echo "configuring /boot/grub/grub.cfg..."
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
        
    echo "Press any key to continue..."; read empty
}

# WIFI (BCM4360) IF NECESSARY
wl_wifi(){
    clear && echo "Installing broadcomm-wl-dkms..."
    #arch-chroot /mnt pacman -S broadcom-wl-dkms
    arch-chroot /mnt pacman -S "${wifi_drivers[@]}"
    [[ "$?" -eq 0 ]] && echo "Wifi Driver installed!"; sleep 3
}

# INSTALL XORG AND DESKTOP
install_desktop(){
    # XORG AND DESKTOP
    clear
    echo "Installing Xorg and Desktop..."

    #basicx=( xorg-server xorg-xinit mesa xorg-twm xterm gnome-terminal xorg-xclock cinnamon nemo-fileroller lightdm xfce4-terminal firefox neofetch screenfetch lightdm-gtk-greeter)

    arch-chroot /mnt pacman -S "${basic_x[@]}"

    #extra_x=( adobe-source-code-pro-fonts cantarell-fonts gnu-free-fonts noto-fonts breeze-gtk breeze-icons oxygen-gtk2 gtk-engine-murrine oxygen-icons xcursor-themes adapta-gtk-theme arc-gtk-theme elementary-icon-theme faenza-icon-theme gnome-icon-theme-extras arc-icon-theme lightdm-webkit-theme-litarvan mate-icon-theme materia-gtk-theme papirus-icon-theme xcursor-bluecurve xcursor-premium archlinux-wallpaper deepin-community-wallpapers deepin-wallpapers elementary-wallpapers )

    ## Also, install fonts and icon and cursor themes
    arch-chroot /mnt pacman -S "${extra_x[@]}"

    # INSTALL DRIVER FOR YOUR GRAPHICS CARD
    #find_card
    #arch-chroot /mnt pacman -Ss | grep 'xf86-video' | more
    #echo "Which driver is yours?"; read driver
    #arch-chroot /mnt pacman -S "$driver"

    #echo "Enabling lightdm service..."
    #arch-chroot /mnt systemctl enable lightdm.service
    #echo && echo "Cinnamon and lightdm should now be installed..."
    #sleep 5

    arch-chroot /mnt pacman -S "${display_mgr[@]} ${graphics_driver[@]} ${cinnamon_desktop[@]}"

    #arch-chroot /mnt systemctl enable "${my_services[@]}"
    for service in "${my_services[@]}"; do
        arch-chroot /mnt systemctl enable "$service"
    done

}

install_extra_stuff(){
    arch-chroot /mnt pacman -S "${all_extras[@]}"
}

check_reflector(){
    clear
    echo "checking if reflector has finished updating mirrorlist yet..."
    while true; do
        pgrep -x reflector &>/dev/null || break
        echo -n '.'
        sleep 2
    done
}


#############################################################
############         START SCRIPT
#############################################################
start(){
    clear
    echo && echo "WELCOME TO DARCHI!  Dave's Arch Install Script!"
    sleep 4

    check_reflector
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
    # OPTIONAL WIFI
    echo && echo "Install drivers for BCM4360? " && read wifi
    [[ "$wifi" =~ [yY] ]] && wl_wifi
    install_grub
    install_desktop
    echo "Type 'shutdown -r now' to reboot..."
}

startmenu(){
    check_reflector
    while true ; do
    clear
    echo -e "\n\n     Welcome to Darchi!   Dave's Archlinux Installer!" 
        echo -e "\n\n\n What do you want to do?  \n\n"
        echo -e "  1) check connection and date   2) Prepare Installation Disk"
        echo -e "\n  3) Install Base System         4) New FSTAB and TZ/Locale"
        echo -e "\n  5) Set new hostname            6) Set new root password"
        echo -e "\n  7) Install more essentials     8) Add user + sudo account"
        echo -e "\n  9) Install BCM4360 drivers     10) Install grub"
        echo -e "\n  11) Install Xorg + Desktop     12) Repopulate Variables"
        echo -e "\n  13) Exit script"


        echo -e "\n\n   Your choice?  "; read menupick

    case $menupick in
        1) check_connect; time_date ;;
        2) get_install_device ;;
        3) install_base ;;
        4) gen_fstab; set_tz; set_local ;;
        5) set_hostname ;;
        6) echo "Setting ROOT password..."; arch-chroot /mnt passwd ;;
        7) install_essential ;;
        8) add_user_acct ;;
        9) wl_wifi ;;
        10) install_grub ;;
        11) install_desktop ;;
        12) set_variables ;;
        13) echo -e "\n  Type 'shutdown -h now' and then remove USB/DVD, then reboot"
            exit 0 ;;
        *) echo "Please make a valid pick from menu!" ;;
    esac
    done
}

#start
startmenu

