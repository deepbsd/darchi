#!/usr/bin/env bash

### Dave's Arch Installer -- execute from archiso iso

### GLOBAL VARIABLES

###  SEARCH FOR lv_create IF USING LVM: CHANGE THESE VARIABLES AS NEEDED
   # IN_DEVICE=/dev/nvme0n1
   # EFI_DEVICE=/dev/nvme0n1p1
   # ROOT_DEVICE=/dev/nvme0n1p2
   # VOL_GROUP=arch_vg
   # LV_ROOT="ArchRoot"
   # LV_HOME="ArchHome"
   # LV_SWAP="ArchSwap"

   # EFI_SIZE=512M
   # ROOT_SIZE=100G
   # HOME_SIZE=     # ALL REMAINING SPACE
   # SWAP_SIZE=32G  # TO BE ABLE TO HYBERNATE

   # populate the disks array for potential installation targets
   : '    
   DISKS=()
   for d in $(lsblk | grep disk | awk '{printf "%s\n%s\n",$1,$4}'); do
        DISKS+=($d)
   done

   max=${#DISKS[@]}
   for ((n=0;n<$max;n+=2)); do
        printf "%s\t\t%s\n" ${DISKS[$n]} ${DISKS[(($n+1))]}
   done
   '

##  Set this
use_lvm(){ return 0; }  # return 0 for true, 1 for false

##  ** Do NOT edit these! They are updated programmatically **
##                        --- for non-lvm systems ---
DISKTABLE=''
IN_DEVICE=''
EFI_SLICE=''
ROOT_SLICE=''
HOME_SLICE=''
SWAP_SLICE=''

# GRAPHICS DRIVERS ETC   ---  change as needed ---
wifi_drivers=(broadcom-wl-dkms iwd)
graphics_driver=(xf86-video-vmware)
display_mgr=(lightdm)
all_extras=( "${xfce_desktop[@]}" "${i3gaps_desktop[@]}" "${mate_desktop[@]}" "${devel_stuff[@]}" "${printing_stuff[@]}" "${multimedia_stuff[@]}" )

# VOL GROUP VARIABLES
USE_LVM=''   # gets set programmatically
VOL_GROUP="arch_vg"
LV_ROOT="ArchRoot"
LV_HOME="ArchHome"

# PARTITION SIZES  (You can edit these if desired)
BOOT_SIZE=512M
EFI_SIZE=512M
ROOT_SIZE=13G
SWAP_SIZE=2G   # SWAP_SIZE="$(free | awk '/^Mem/ {mem=$2/1000000; print int(2.2*mem)}')G"
HOME_SIZE=12G   # This is set automatically if using LVM

# You can edit this if you want
TIMEZONE='America/New_York'
LOCALE="en_US.UTF-8"

###########  SOFTWARE SETS ###################

# replace with linux-lts or -zen if preferrable
base_system=( base base-devel linux linux-headers dkms linux-firmware vim sudo bash-completion )

base_essentials=(git mlocate pacman-contrib man-db man-pages)

network_essentials=( iwd dhcpcd openssh networkmanager )

#display_mgr=(lightdm)

my_services=( dhcpcd sshd NetworkManager lightdm )

basic_x=( xorg-server xorg-xinit mesa xorg-twm xterm gnome-terminal xorg-xclock xfce4-terminal firefox neofetch screenfetch lightdm-gtk-greeter )

extra_x=( gkrellm powerline powerline-fonts powerline-vim adobe-source-code-pro-fonts cantarell-fonts gnu-free-fonts noto-fonts breeze-gtk breeze-icons oxygen-gtk2 gtk-engine-murrine oxygen-icons xcursor-themes adapta-gtk-theme arc-gtk-theme elementary-icon-theme faenza-icon-theme gnome-icon-theme-extras arc-icon-theme lightdm-webkit-theme-litarvan mate-icon-theme materia-gtk-theme papirus-icon-theme xcursor-bluecurve xcursor-premium archlinux-wallpaper deepin-community-wallpapers deepin-wallpapers elementary-wallpapers )

#graphics_driver=(xf86-video-vmware)

cinnamon_desktop=( cinnamon nemo-fileroller )

#####  Include in 'all_extras' array if desired
xfce_desktop=( xfce4 xfce4-goodies )

mate_desktop=( mate mate-extra )

i3gaps_desktop=( i3-gaps dmenu feh rofi i3status i3blocks nitrogen i3status ttf-font-awesome ttf-ionicons )

## Python3 should be installed by default
devel_stuff=( git nodejs npm npm-check-updates ruby )

printing_stuff=( system-config-printer foomatic-db foomatic-db-engine gutenprint cups cups-pdf cups-filters cups-pk-helper ghostscript gsfonts )

multimedia_stuff=( brasero sox cheese eog shotwell imagemagick sox cmus mpg123 alsa-utils cheese )

##  fonts_themes=()    #  in case I want to break these out from extra_x

#all_extras=( "${xfce_desktop[@]}" "${i3gaps_desktop[@]}" "${mate_desktop[@]}" "${devel_stuff[@]}" "${printing_stuff[@]}" "${multimedia_stuff[@]}" )

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

# PARTITION NON-LVM DISK
part_disk(){
    device=$1 ; IN_DEVICE="/dev/$device"
    if $(efi_boot_mode); then
            echo && echo "Recommend efi (512MB), root (100G), home (remaining), swap (32G) partitions..."
            echo && echo "Continue to sgdisk? "; read answer
            [[ "$answer" =~ [yY] ]] && echo "paritioning with sgdisk..."
            sgdisk -Z "$IN_DEVICE"
            sgdisk -n 1::+"$EFI_SIZE" -t 1:ef00 -c 1:EFI "$IN_DEVICE"
            sgdisk -n 2::+"$ROOT_SIZE" -t 2:8300 -c 2:ROOT "$IN_DEVICE"
            sgdisk -n 3::+"$SWAP_SIZE" -t 3:8200 -c 3:SWAP "$IN_DEVICE"
            sgdisk -n 4 -c 4:HOME "$IN_DEVICE"
    else
        # For non-EFI. Eg. for MBR systems 
cat > /tmp/sfdisk.cmd << EOF
$BOOT_DEVICE : start= 2048, size=+$BOOT_SIZE, type=83, bootable
$ROOT_DEVICE : size=+$ROOT_SIZE, type=83
$SWAP_DEVICE : size=+$SWAP_SIZE, type=82
$HOME_DEVICE : type=83
EOF
        # Using sfdisk because we're talking MBR disktable now...
        sfdisk /dev/sda < /tmp/sfdisk.cmd 
    fi

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
    # install lvm2 if we're using LVM
    use_lvm && base_system+=( "lvm2" )
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
    echo && echo "Installing dhcpcd, sshd and NetworkManager services..."
    echo
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
    sleep 4
    vim /mnt/etc/mkinitcpio.conf
    arch-chroot /mnt mkinitcpio -P
    echo "Press any key to continue..."; read empty
}

lv_create(){
    VOL_GROUP=arch_vg
    LV_ROOT="ArchRoot"
    LV_HOME="ArchHome"
    LV_SWAP="ArchSwap"

    echo "What disk are you installing to? (nvme0n1, sda, sdb, etc)"; read disk
    IN_DEVICE=/dev/"$disk"
    echo "What partition is your Physical Device for your Volume Group? (sda2, nvme0n1p2, sdb2, etc)"; read root_dev
    ROOT_DEVICE=/dev/"$root_dev"
    echo "How big is your root partition? (12G, 50G, 100G, etc)"; read rootsize
    ROOT_SIZE="$rootsize"
    echo "How big is your Swap partition?"; read swap_size
    SWAP_SIZE="$swap_size"
    #HOME_SIZE=16G

    if $(efi_boot_mode); then
        echo "What partition is your EFI device? (nvme0n1p1, sda1, etc)"; read efi_dev
        EFI_DEVICE=/dev/"$efi_dev"
        EFI_SIZE=512M
        # Create the physical partitions
        sgdisk -Z "$IN_DEVICE"
        sgdisk -n 1::+"$EFI_SIZE" -t 1:ef00 -c 1:EFI "$IN_DEVICE"
        sgdisk -n 2 -t 2:8e00 -c 2:VOLGROUP "$IN_DEVICE"

        # Format the EFI partition
        mkfs.fat -F32 "$EFI_DEVICE"
    else
        echo "What partition is your BOOT device? (nvme0n1p1, sda1, etc)"; read boot_dev
        BOOT_DEVICE=/dev/"$boot_dev"
        BOOT_SIZE=512M

cat > /tmp/sfdisk.cmd << EOF
$BOOT_DEVICE : start= 2048, size=+$BOOT_SIZE, type=83, bootable
$ROOT_DEVICE : type=83
EOF
        # Using sfdisk because we're talking MBR disktable now...
        sfdisk /dev/sda < /tmp/sfdisk.cmd 

        # format the boot partition
        mkfs.ext4 "$BOOT_DEVICE"
    fi

    clear

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
    ## format the volumes
    #mkfs.fat -F32 "$EFI_DEVICE"
    mkfs.ext4 /dev/"$VOL_GROUP"/"$LV_ROOT"
    mkfs.ext4 /dev/"$VOL_GROUP"/"$LV_HOME"
    # mount the volumes
    mount /dev/"$VOL_GROUP"/"$LV_ROOT" /mnt
    mkdir /mnt/home
    mount /dev/"$VOL_GROUP"/"$LV_HOME" /mnt/home
    if $(efi_boot_mode); then
        # mount the EFI partitions
        mkdir /mnt/boot && mkdir /mnt/boot/efi
        mount "$EFI_DEVICE" /mnt/boot/efi
    else
        mkdir /mnt/boot
        mount "$BOOT_DEVICE" /mnt/boot
    fi
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
        echo -e "    1) Check connection and date  2) Prepare Installation Disk"
        echo -e "\n  3) Install Base System        4) Install mkinitcpio hooks for LVM "
        echo -e "\n  5) New FSTAB and TZ/Locale    6) Set new hostname"
        echo -e "\n  7) Set new root password      8) Install more essentials "
        echo -e "\n  9) Add user + sudo account    10) Install BCM4360 drivers  "
        echo -e "\n  11) Install grub              12) Install Xorg + Desktop"
        echo -e "\n  13) Install Extra Window Mgrs  14) Repopulate Variables "
        echo -e "\n  15) Exit Script"


        echo -e "\n\n   Your choice?  "; read menupick

    case $menupick in
        1) check_connect; time_date ;;
        2) diskmenu ;;
        3) install_base ;;
        4) lvm_hooks ;;
        5) gen_fstab; set_tz; set_locale ;;
        6) set_hostname ;;
        7) echo "Setting ROOT password..."; 
            arch-chroot /mnt passwd; 
            echo "Any key to continue..."; read continue ;;
        8) install_essential ;;
        9) add_user_acct ;;
        10) wl_wifi ;;
        11) install_grub ;;
        12) install_desktop ;;
        13) install_extra_stuff ;;
        14) set_variables ;;
        15) echo -e "\n  Type 'shutdown -h now' and then remove USB/DVD, then reboot"
            exit 0 ;;
        *) echo "Please make a valid pick from menu!" ;;
    esac
    done
}

#start
startmenu

