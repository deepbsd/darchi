#!/usr/bin/env bash

### Dave's Arch Installer -- execute from archiso 

# KEYBOARD: default console keymap is US so no need to change

### GLOBAL VARIABLES
##  ** Do NOT edit these! They are updated programmatically **
DISKTABLE=''
IN_DEVICE=''
EFI_SLICE=''
ROOT_SLICE=''
HOME_SLICE=''
SWAP_SLICE=''

# VOL GROUP VARIABLES
USE_LVM=''   # gets set programmatically
VOL_GROUP="arch_vg"
LV_ROOT="ArchRoot"
LV_HOME="ArchHome"

# PARTITION SIZES  (You can edit these if desired)
EFI_SIZE=512M
ROOT_SIZE=13G
SWAP_SIZE=2G
HOME_SIZE=12G   # This is set automatically if using LVM

# You can edit this if you want
TIMEZONE='America/New_York'
LOCALE="en_US.UTF-8"

###########  SOFTWARE SETS ###################

# replace with linux-lts or -zen if preferrable
base_system=( base base-devel linux linux-headers dkms linux-firmware vim sudo bash-completion )

base_essentials=(git mlocate pacman-contrib man-db man-pages)

network_essentials=( dhcpcd openssh networkmanager )

display_mgr=(lightdm)

my_services=( dhcpcd sshd NetworkManager lightdm )

basic_x=( xorg-server xorg-xinit mesa xorg-twm xterm gnome-terminal xorg-xclock xfce4-terminal firefox neofetch screenfetch lightdm-gtk-greeter )

extra_x=( gkrellm powerline powerline-fonts powerline-vim adobe-source-code-pro-fonts cantarell-fonts gnu-free-fonts noto-fonts breeze-gtk breeze-icons oxygen-gtk2 gtk-engine-murrine oxygen-icons xcursor-themes adapta-gtk-theme arc-gtk-theme elementary-icon-theme faenza-icon-theme gnome-icon-theme-extras arc-icon-theme lightdm-webkit-theme-litarvan mate-icon-theme materia-gtk-theme papirus-icon-theme xcursor-bluecurve xcursor-premium archlinux-wallpaper deepin-community-wallpapers deepin-wallpapers elementary-wallpapers )

graphics_driver=(xf86-video-vmware)

wifi_drivers=(broadcom-wl-dkms)

cinnamon_desktop=( cinnamon nemo-fileroller )

#####  Include in 'all_extras' array if desired
xfce_desktop=( xfce4 xfce4-goodies )

mate_desktop=( mate mate-extra )

i3gaps_desktop=( i3-gaps dmenu feh rofi i3status i3blocks
    nitrogen i3status ttf-font-awesome
    ttf-ionicons )

## Python3 should be installed by default
devel_stuff=( git nodejs npm npm-check-updates ruby )

printing_stuff=( system-config-printer foomatic-db foomatic-db-engine gutenprint cups cups-pdf cups-filters cups-pk-helper ghostscript gsfonts )

multimedia_stuff=( eog shotwell imagemagick sox cmus mpg123 alsa-utils
    cheese )

##  fonts_themes=()    #  in case I want to break these out from extra_x

all_extras=( "${xfce_desktop[@]}" "${i3gaps_desktop[@]}" "${mate_desktop[@]}" "${devel_stuff[@]}" "${printing_stuff[@]}" "${multimedia_stuff[@]}" )

##########################################
###########  FUNCTIONS ###################
##########################################

# USING LVM?
use_lvm(){
    [[ -d /dev/"$VOL_GROUP" ]] && USE_LVM='true' && return 0
    return 1
}

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
    echo && echo "Continue to sgdisk? "; read answer
    [[ "$answer" =~ [yY] ]] && echo "paritioning with sgdisk..."
    sgdisk -Z "$IN_DEVICE"
    sgdisk -n 1::+"$EFI_SIZE" -t 1:ef00 -c 1:EFI "$IN_DEVICE"
    sgdisk -n 2::+"$ROOT_SIZE" -t 2:8300 -c 2:ROOT "$IN_DEVICE"
    sgdisk -n 3::+"$SWAP_SIZE" -t 3:8200 -c 3:SWAP "$IN_DEVICE"
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
    echo && echo "setting timezone to $TIMEZONE..."
    arch-chroot /mnt ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
    arch-chroot /mnt hwclock --systohc --utc
    arch-chroot /mnt date
    echo && echo "Does date look correct?"; read td_yn
    [[ "$td_yn" =~ [yY] ]] || exit 0

}

# LOCALE
set_locale(){
    clear
    echo && echo "setting locale to $LOCALE..."
    sleep 3
    arch-chroot /mnt sed -i "s/#$LOCALE/$LOCALE/g" /etc/locale.gen
    arch-chroot /mnt locale-gen
    sleep 3
    echo "LANG=$LOCALE" > /mnt/etc/locale.conf
    export LANG="$LOCALE"
    sleep 3
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
    echo && echo "Installing (lvm2?) dhcpcd, sshd and NetworkManager services..."
    echo
    # install lvm2 if we're using LVM
    use_lvm && base_essentials+=( "lvm2" )
    arch-chroot /mnt pacman -S "${base_essentials[@]}"
    arch-chroot /mnt pacman -S "${network_essentials[@]}"

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
    clear && echo "Installing $wifi_drivers..."
    arch-chroot /mnt pacman -S "${wifi_drivers[@]}"
    [[ "$?" -eq 0 ]] && echo "Wifi Driver installed!"; sleep 3
}

# INSTALL XORG AND DESKTOP
install_desktop(){
    # XORG AND DESKTOP
    clear
    echo "Installing Xorg and Desktop..."


    arch-chroot /mnt pacman -S "${basic_x[@]}"
    arch-chroot /mnt pacman -S "${extra_x[@]}"

    # DRIVER FOR GRAPHICS CARD, DESKTOP, DISPLAY MGR
    arch-chroot /mnt pacman -S "${display_mgr[@]}"     
    arch-chroot /mnt pacman -S "${graphics_driver[@]}" 
    arch-chroot /mnt pacman -S "${cinnamon_desktop[@]}"

    # ENABLE SERVICES
    for service in "${my_services[@]}"; do
        arch-chroot /mnt systemctl enable "$service"
    done

    echo "Type any key to continue..."; read empty
}

install_extra_stuff(){

    arch-chroot /mnt pacman -S "${all_extras[@]}"

    # restart services so lightdm gets all WM picks
    for service in "${my_services[@]}"; do
        arch-chroot /mnt systemctl enable "$service"
    done
    
    echo "Type any key to continue..."; read empty
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

lvm_hooks(){
    clear
    echo "add lvm2 to mkinitcpio hooks HOOKS=( base udev ... block lvm2 filesystems )"
    sleep 5
    vim /mnt/etc/mkinitcpio.conf
    arch-chroot /mnt mkinitcpio -P
    echo "Press any key to continue..."; read empty
}

lv_create(){
    IN_DEVICE=/dev/sda
    EFI_DEVICE=/dev/sda1
    ROOT_DEVICE=/dev/sda2
    VOL_GROUP=arch_vg
    LV_ROOT="ArchRoot"
    LV_HOME="ArchHome"
    LV_SWAP="ArchSwap"

    EFI_SIZE=512M
    ROOT_SIZE=12G
    HOME_SIZE=16G
    SWAP_SIZE=2G

    clear

    # Create the physical partitions
    sgdisk -Z "$IN_DEVICE"
    sgdisk -n 1::+"$EFI_SIZE" -t 1:ef00 -c 1:EFI "$IN_DEVICE"
    sgdisk -n 2 -t 2:8e00 -c 2:VOLGROUP "$IN_DEVICE"
    # Format the EFI partition
    mkfs.fat -F32 "$EFI_DEVICE"

    # create the physical volumes
    pvcreate "$ROOT_DEVICE"
    # create the volume group
    vgcreate "$VOL_GROUP" "$ROOT_DEVICE" 
    
    # You can extend with 'vgextend' to other devices too

    # create the volumes with specific size
    lvcreate -L "$ROOT_SIZE" "$VOL_GROUP" -n "$LV_ROOT"
    lvcreate -L "$SWAP_SIZE" "$VOL_GROUP" -n "$LV_SWAP"
    lvcreate -l 100%FREE  "$VOL_GROUP" -n "$LV_HOME"
    
    # Format SWAP 
    mkswap /dev/"$VOL_GROUP"/"$LV_SWAP"
    swapon /dev/"$VOL_GROUP"/"$LV_SWAP"

    # insert the vol group module
    modprobe dm_mod
    # activate the vol group
    vgchange -ay
    # format the volumes
    mkfs.ext4 /dev/"$VOL_GROUP"/"$LV_ROOT"
    mkfs.ext4 /dev/"$VOL_GROUP"/"$LV_HOME"
    # mount the volumes
    mount /dev/"$VOL_GROUP"/"$LV_ROOT" /mnt
    mkdir /mnt/home
    mount /dev/"$VOL_GROUP"/"$LV_HOME" /mnt/home
    # mount the EFI partitions
    mkdir /mnt/boot && mkdir /mnt/boot/efi
    mount /dev/sda1 /mnt/boot/efi
    lsblk
    echo "LVs created and mounted. Press any key."; read empty;
    startmenu
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
    install_extra_stuff
    echo "Type 'shutdown -r now' to reboot..."
}

diskmenu(){
    clear
    while true ; do
        echo -e "\n\n     Prepare Installation Disk (Choose One)" 
        echo -e "  1) Prepare Installation Disk with Normal Partitions"
        echo -e "  2) Prepare Installation Disk with LVM"

        echo -e "\n\n   Your choice?  "; read diskmenupick

    case $diskmenupick in
        1) get_install_device ;;
        2) lv_create ;;
        *) echo "Please make a valid pick from menu!" ;;
    esac
    done
}

startmenu(){
    check_reflector
    while true ; do
    clear
    echo -e "\n\n     Welcome to Darchi!   Dave's Archlinux Installer!" 
        echo -e "\n\n\n What do you want to do?  \n\n"
        echo -e "  1) Check connection and date   2) Prepare Installation Disk"
        echo -e "\n  3) Install Base System         4) New FSTAB and TZ/Locale"
        echo -e "\n  5) Set new hostname            6) Set new root password"
        echo -e "\n  7) Install more essentials     8) Add user + sudo account"
        echo -e "\n  9) Install BCM4360 drivers     10) Install grub"
        echo -e "\n  10a) Install mkinitcpio hooks for LVM"
        echo -e "\n  11) Install Xorg + Desktop     12) Install Extra Stuff"
        echo -e "\n  13) Repopulate Variables       14) Exit Script"


        echo -e "\n\n   Your choice?  "; read menupick

    case $menupick in
        1) check_connect; time_date ;;
        2) diskmenu ;;
        3) install_base ;;
        4) gen_fstab; set_tz; set_locale ;;
        5) set_hostname ;;
        6) echo "Setting ROOT password..."; 
            arch-chroot /mnt passwd; 
            echo "Any key to continue..."; read continue ;;
        7) install_essential ;;
        8) add_user_acct ;;
        9) wl_wifi ;;
        10) install_grub ;;
        10a) lvm_hooks ;;
        11) install_desktop ;;
        12) install_extra_stuff ;;
        13) set_variables ;;
        14) echo -e "\n  Type 'shutdown -h now' and then remove USB/DVD, then reboot"
            exit 0 ;;
        *) echo "Please make a valid pick from menu!" ;;
    esac
    done
}

#start
startmenu

