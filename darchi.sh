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

# Pick an editor
#EDITOR=vim    # I don't edit by hand anymore
sudo_user="dsj"   #  gets added programmatically; needs to be in global space

# VOL GROUP VARIABLES
USE_LVM=''   # gets set programmatically
USE_CRYPT='' # gets set programmatically
VOL_GROUP="arch_vg"
LV_ROOT="ArchRoot"
LV_HOME="ArchHome"
LV_SWAP="ArchSwap"

# PARTITION SIZES  (You can edit these if desired)
BOOT_SIZE=512M
EFI_SIZE=512M
#ROOT_SIZE=13G   # For VM
ROOT_SIZE=100G
#SWAP_SIZE=2G   # SWAP_SIZE="$(free | awk '/^Mem/ {mem=$2/1000000; print int(2.2*mem)}')G"
SWAP_SIZE=64G   # SWAP_SIZE="$(free | awk '/^Mem/ {mem=$2/1000000; print int(2.2*mem)}')G"
#HOME_SIZE=13G   # This is set automatically if using LVM

# GRAPHICS DRIVERS ETC   ---  change as needed ---
wifi_drivers=(broadcom-wl-dkms iwd)
graphics_driver=(xf86-video-vmware)
display_mgr=(lightdm)

# You can edit this if you want
TIMEZONE='America/New_York'
LOCALE="en_US.UTF-8"



##  ** Do NOT edit these! They are updated programmatically **
##
## Note: these all of these variables must be in the global namespace
##       so they can be updated from functions later on
DISKTABLE=''
IN_DEVICE=''
EFI_SLICE=''
ROOT_SLICE=''
HOME_SLICE=''
SWAP_SLICE=''

###########  SOFTWARE SETS ###################

# replace with linux-lts or -zen if preferrable
base_system=( base base-devel linux linux-headers dkms linux-firmware vim sudo bash-completion archlinux-keyring )

base_essentials=(git mlocate pacman-contrib man-db man-pages)

network_essentials=( iwd dhcpcd openssh networkmanager )

my_services=( dhcpcd sshd NetworkManager systemd-homed )

basic_x=( xorg-server xorg-xinit mesa xorg-twm xterm gnome-terminal xorg-xclock xfce4-terminal firefox neofetch fastfetch screenfetch lightdm-gtk-greeter )

extra_x1=( gkrellm powerline powerline-fonts powerline-vim adobe-source-code-pro-fonts cantarell-fonts gnu-free-fonts ) 

extra_x2=( noto-fonts breeze-gtk breeze-icons gtk-engine-murrine oxygen-icons xcursor-themes adapta-gtk-theme )

extra_x3=( arc-gtk-theme elementary-icon-theme gnome-icon-theme-extras arc-icon-theme lightdm-webkit-theme-litarvan mate-icon-theme ) 

extra_x4=( materia-gtk-theme papirus-icon-theme archlinux-wallpaper deepin-community-wallpapers deepin-wallpapers elementary-wallpapers )

cinnamon_desktop=( cinnamon nemo-fileroller )

#####  Include in 'all_extras' array if desired
xfce_desktop=( xfce4 xfce4-goodies )

mate_desktop=( mate mate-extra )

i3gaps_desktop=( i3-gaps dmenu feh rofi i3status i3blocks nitrogen i3status ttf-font-awesome ttf-ionicons )

qtile_desktop=( qtile dmenu feh rofi rofi nitrogen ttf-font-awesome ttf-ionicons  )

kde_desktop=( plasma plasma-wayland-session kde-applications )

## Python3 should be installed by default
devel_stuff=( git nodejs npm npm-check-updates ruby )

printing_stuff=( system-config-printer foomatic-db foomatic-db-engine gutenprint cups cups-pdf cups-filters cups-pk-helper ghostscript gsfonts )

multimedia_stuff=( brasero sox cheese eog shotwell imagemagick sox cmus mpg123 alsa-utils cheese )

all_extras=( "${xfce_desktop[@]}" "${i3gaps_desktop[@]}" "${mate_desktop[@]}" "${devel_stuff[@]}" "${printing_stuff[@]}" "${multimedia_stuff[@]}" )

##  fonts_themes=()    #  in case I want to break these out from extra_x

# This will exclude services because they are often named differently and are duplicates
all_pkgs=( base_system base_essentials network_essentials basic_x extra_x1 extra_x2 extra_x3 extra_x4 cinnamon_desktop xfce_desktop mate_desktop i3gaps_desktop devel_stuff printing_stuff multimedia_stuff qtile_desktop kde_desktop )

completed_tasks=()

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
    $(ping -c 3 archlinux.org &>/dev/null) ||  not_connected
    echo "Good!  We're connected!!!" && sleep 4
}

# CHECK IF TASK IS COMPLETED
check_tasks(){
    # If task already exists in array return falsey
    # Function takes a task number as an argument
    [[ "${completed_tasks[@]}" =~ $1 ]] && return 1
    completed_tasks+=( "$1" )
    return 0
}

# VALIDATE PKG NAMES IN SCRIPT
validate_pkgs(){
    echo && echo -n "    validating pkg names..."
    for pkg_arr in "${all_pkgs[@]}"; do
        declare -n arr_name=$pkg_arr
        for pkg_name in "${arr_name[@]}"; do
            if $( pacman -Sp $pkg_name &>/dev/null ); then
                echo -n .
            else 
                echo -n "$pkg_name from $pkg_arr not in repos."
            fi
        done
    done
    echo -e "\n" && read -p "Press any key to continue." empty
}

# UPDATE SYSTEM CLOCK
time_date(){
    timedatectl set-ntp true
    echo && echo "Date/Time service Status is . . . "
    timedatectl status
    sleep 4
}

show_disks(){
   echo "Here are the available disks in your system: "
   DISKS=()
   for d in $(lsblk | grep disk | awk '{printf "%s\n%s\n",$1,$4}'); do
        DISKS+=($d)
   done

   max=${#DISKS[@]}
   for ((n=0;n<$max;n+=2)); do
        printf "%s\t\t%s\n" ${DISKS[$n]} ${DISKS[(($n+1))]}
   done
   echo
}

# ENCRYPT DISK WHEN POWER IS OFF
crypt_setup(){
    # Takes a disk partition as an argument
    # Give msg to user about purpose of encrypted physical volume
    cat <<END_OF_MSG

"You are about to encrypt a physical volume.  Your data will be stored in an encrypted
state when powered off.  Your files will only be protected while the system is powered off.
This could be very useful if your laptop gets stolen, for example."

END_OF_MSG
    read -p "Encrypting a disk partition. Please enter a memorable passphrase: " -s passphrase
    #echo -n "$passphrase" | cryptsetup -q luksFormat $1 -
    echo "$passphrase" | cryptsetup -q luksFormat --hash=sha512 --key-size=512 --cipher=aes-xts-plain64 --verify-passphrase $1

    cryptsetup luksOpen  $1 sda_crypt
    echo "Wiping every byte of device with zeros, could take a while..."
    dd if=/dev/zero of=/dev/mapper/sda_crypt bs=1M
    cryptsetup luksClose sda_crypt
    echo "Filling header of device with random data..."
    dd if=/dev/urandom of="$1" bs=512 count=20480
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

    lsblk -f "$IN_DEVICE" && echo "Home device name? (leave empty if no home device)"; read home_device
    HOME_SLICE="/dev/$home_device"
    echo "Formatting $HOME_SLICE" && sleep 2
    [[ -n "$home_device" ]] && format_disk "$HOME_SLICE" home

    lsblk -f "$IN_DEVICE"
    echo && echo "Disks should be partioned and mounted.  Continue?"; lsblk ; read more
    [[ ! "$more" =~ [yY] ]] && exit 1
}

# INSTALL TO WHAT DEVICE?
get_install_device(){
    clear
    echo "Available installation media: "  && echo
    show_disks

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
    # install lvm2 hook if we're using LVM
    [[ $USE_LVM == 'TRUE'  ]] && base_system+=( "lvm2" )
    pacstrap /mnt "${base_system[@]}"
    [[ -L /dev/mapper/arch_vg-ArchRoot ]] && lvm_hooks
    echo && echo "Base system installed.  Press any key to continue..."; read empty
}

# GENERATE FSTAB
gen_fstab(){
    clear
    echo "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
    sleep 3

    # EDIT FSTAB IF NECESSARY
    clear
    echo && echo "Here's the new /etc/fstab..."; cat /mnt/etc/fstab
    echo && echo "Type any key to continue..."; read empty
}

# TIMEZONE
set_tz(){
    clear
    echo && echo "setting timezone to $TIMEZONE..."
    arch-chroot /mnt ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
    arch-chroot /mnt hwclock --systohc --utc
    arch-chroot /mnt date
    echo && echo "Press any key to continue..."; read td_yn
    #return 0
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
    echo && echo "Press any key to continue"; read loc_yn
    #return 0
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
    echo && echo "Press any key to continue"; read etchosts_yn
    #return 0
}

# SOME MORE ESSENTIAL NETWORK STUFF
install_essential(){
    clear
    echo && echo "Installing dhcpcd, sshd and NetworkManager services..."
    echo
    arch-chroot /mnt pacman -S "${base_essentials[@]}"
    arch-chroot /mnt pacman -S "${network_essentials[@]}"

    # ENABLE SERVICES
    for service in "${my_services[@]}"; do
        arch-chroot /mnt systemctl enable "$service"
    done

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
    echo "Available block devices: "; lsblk
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

    # EXTRA PACKAGES, FONTS, THEMES, CURSORS
    arch-chroot /mnt pacman -S "${basic_x[@]}"
    arch-chroot /mnt pacman -S "${extra_x1[@]}"
    arch-chroot /mnt pacman -S "${extra_x2[@]}"
    arch-chroot /mnt pacman -S "${extra_x3[@]}"
    arch-chroot /mnt pacman -S "${devel_stuff[@]}"
    arch-chroot /mnt pacman -S "${multimedia_stuff[@]}"
    arch-chroot /mnt pacman -S "${printing_stuff[@]}"

    # DRIVER FOR GRAPHICS CARD, DESKTOP, DISPLAY MGR
    arch-chroot /mnt pacman -S "${display_mgr[@]}"     
    arch-chroot /mnt pacman -S "${graphics_driver[@]}" 
    ## Insert your default desktop here...
    arch-chroot /mnt pacman -S "${cinnamon_desktop[@]}"

    arch-chroot /mnt systemctl enable "${display_mgr[@]}"

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
    ### This was the old way of doing it... by hand with your editor...
    #echo "add lvm2 to mkinitcpio hooks HOOKS=( base udev ... block lvm2 filesystems )"
    #sleep 4
    #vim /mnt/etc/mkinitcpio.conf

    #Add lvm2 to mkinitcpio.conf and remake the init image
    sed -i 's/^\(HOOKS=["(]base .*\) filesystems \(.*\)$/\1 lvm2 filesystems \2/g' /mnt/etc/mkinitcpio.conf
    arch-chroot /mnt mkinitcpio -P

    echo "Going to page through your mkinitcpio.conf file; check your HOOKS for presence of lvm2 or not"
    sleep 5
    less /mnt/etc/mkinitcpio.conf
}

lv_create(){
    USE_LVM='TRUE'
    VOL_GROUP=arch_vg
    LV_ROOT="ArchRoot"
    LV_HOME="ArchHome"
    LV_SWAP="ArchSwap"

    #lsblk
    show_disks

    echo "What disk are you installing to? (nvme0n1, sda, sdb, etc)"; read disk
    IN_DEVICE="/dev/$disk"
    echo "What partition is your Physical Device for your Volume Group? (sda2, nvme0n1p2, sdb2, etc)"; read root_dev
    ROOT_DEVICE="/dev/$root_dev"

    echo "How big is your root partition or volume? (15G, 50G, 100G, etc)"; read rootsize
    ROOT_SIZE="$rootsize"
    echo "How big is your Swap partition or volume? (2G, 4G, 8G, 16G, etc)"; read swap_size
    SWAP_SIZE="$swap_size"

    if $(efi_boot_mode); then
        echo "What partition is your EFI device? (nvme0n1p1, sda1, etc)"; read efi_dev
        EFI_DEVICE="/dev/$efi_dev"
        EFI_SIZE=512M
        # Create the physical partitions
        sgdisk -Z "$IN_DEVICE"
        sgdisk -n 1::+"$EFI_SIZE" -t 1:ef00 -c 1:EFI "$IN_DEVICE"
        sgdisk -n 2 -t 2:8e00 -c 2:VOLGROUP "$IN_DEVICE"

        # Format the EFI partition
        mkfs.fat -F32 "$EFI_DEVICE"
    else
        echo "What partition is your BOOT device? (nvme0n1p1, sda1, etc)"; read boot_dev
        BOOT_DEVICE="/dev/$boot_dev"
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
    
    # run cryptsetup on root device
    [[ "$USE_CRYPT" == 'TRUE' ]] && crypt_setup "$ROOT_DEVICE"

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
    mkswap "/dev/$VOL_GROUP/$LV_SWAP"
    swapon "/dev/$VOL_GROUP/$LV_SWAP"

    # insert the vol group module
    modprobe dm_mod
    # activate the vol group
    vgchange -ay
    ## format the volumes
    #mkfs.fat -F32 "$EFI_DEVICE"
    mkfs.ext4 "/dev/$VOL_GROUP/$LV_ROOT"
    mkfs.ext4 "/dev/$VOL_GROUP/$LV_HOME"
    # mount the volumes
    mount "/dev/$VOL_GROUP/$LV_ROOT" /mnt
    mkdir /mnt/home
    mount "/dev/$VOL_GROUP/$LV_HOME" /mnt/home
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

## INSTALL PARU (ROOT as SUDO USER)
install_paru(){
    # check if paru is already installed
    if $( pacman -Qi paru ); then
        echo "paru already installed! returning now to menu..." 
        sleep 5
        return 0
    fi

    # $1 will be the sudo user in question
    cd /mnt/home/$1
    [ -d $HOME/build ] || su -c "mkdir $HOME/build" $1
    cd $HOME/build
    su -c "git clone https://aur.archlinux.org/paru.git" $1
    cd paru
    su -c "makepkg -si" $1
    ( [ "$?" == 0 ] && echo "Paru build successful!!" ) || echo "Problem building Paru!!!"
    sleep 4
    pacman -Qi paru
}

diskmenu(){
    clear
    check_tasks 2
    while true ; do
        echo -e "\n\n     Prepare Installation Disk (Choose One)" 
        echo -e "  1) Prepare Installation Disk with Normal Partitions"
        echo -e "  2) Prepare Installation Disk with LVM"
        echo -e "  3) Prepare Installation Disk Encryption and LVM"
        echo -e "  4) Return to previous menu"
        echo -e "\n\n"

        echo -e "\n\n   Your choice?  "; read diskmenupick

    case $diskmenupick in
        1) get_install_device ;;
        2) lv_create ;;
        3) USE_CRYPT='TRUE'; lv_create ;;
        4) startmenu ;;
        *) echo "Please make a valid pick from menu!" ;;
    esac
    done
}

#############################################################
############         START SCRIPT
#############################################################

startmenu(){
    check_reflector
    while true ; do
        clear
        echo -e "\n\n     Welcome to Darchi!   Dave's Archlinux Installer!" 
            echo -e "\n\n\n What do you want to do?  \n\n"
            echo -e "  1) Check connection and date   2) Prepare Installation Disk"
            echo -e "\n  3) Install Base System        4) New FSTAB and TZ/Locale "
            echo -e "\n  5) Set new hostname           6) Set root password "
            echo -e "\n  7) Install more essentials    8) Add user + sudo account "
            echo -e "\n  9) Install Wifi Drivers      10) Install grub "
            echo -e "\n  11) Install Xorg + Desktop   12) Install Extra Window Mgrs "
            echo -e "\n  13) Repopulate Variables     14) Check for pkg name changes "
            echo -e "\n  15) Install paru for sudo user added in 8)     "
            echo -e "\n  16) Exit Script     "
            echo -e "\n  "
            echo -e "\n  Tasks completed:  ${completed_tasks[@]}"


            echo -ne "\n\n   Your choice?  "; read menupick

        case $menupick in
            1) check_connect; time_date; check_tasks 1 ;;
            2) diskmenu;;
            3) install_base; check_tasks 3 ;;
            4) gen_fstab; set_tz; set_locale; check_tasks 4 ;;
            5) set_hostname; check_tasks 5 ;;
            6) echo "Setting ROOT password..."; 
                arch-chroot /mnt passwd; 
                check_tasks 6
                echo "Any key to continue..."; read continue ;;
            7) install_essential; check_tasks 7 ;;
            8) add_user_acct; check_tasks 8 ;;
            9) wl_wifi; check_tasks 9 ;;
            10) install_grub; check_tasks 10 ;;
            11) install_desktop; check_tasks 11 ;;
            12) install_extra_stuff; check_tasks 12 ;;
            13) set_variables; check_tasks 13 ;;
            14) validate_pkgs; check_tasks 14 ;;
            15) install_paru $sudo_user; check_tasks 15 ;;
            16) echo -e "\n  Type 'shutdown -h now' and then remove USB/DVD, then reboot"
                exit 0 ;;
            *) echo "Please make a valid pick from menu!" ;;
        esac
    done
}

startmenu

