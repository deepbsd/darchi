#!/usr/bin/env bash

IN_DEVICE=/dev/sda
EFI_DEVICE=/dev/sda1
SWAP_DEVICE=/dev/sda2
ROOT_DEVICE=/dev/sda3
#HOME_DEVICE=/dev/sda4
VOL_GROUP=arch_vg
#ROOT_GROUP=root_vg
#HOME_GROUP=home_vg

EFI_SIZE=512M
ROOT_SIZE=12G
HOME_SIZE=16G
SWAP_SIZE=2G

lv_create(){
    # Create the physical partitions
    sgdisk -Z "$IN_DEVICE"
    sgdisk -n 1::+"$EFI_SIZE" -t 1:ef00 -c 1:EFI "$IN_DEVICE"
    sgdisk -n 2::+"$SWAP_SIZE" -t 2:8200 -c 2:SWAP "$IN_DEVICE"
    sgdisk -n 3 -t 3:8e00 -c 3:VOLGROUP "$IN_DEVICE"
    # Format the EFI partition
    mkfs.fat -F32 "$SWAP_DEVICE"
    # Format SWAP 
    mkswap "$SWAP_DEVICE"
    swapon "$SWAP_DEVICE"
    # create the root and home physical volumes
    pvcreate "$ROOT_DEVICE"
    #pvcreate "$HOME_DEVICE"
    # create the volume groups
    #vgcreate root_vg "$ROOT_DEVICE"
    #vgcreate "$VOL_GROUP" "$ROOT_DEVICE" "$HOME_DEVICE"
    vgcreate "$VOL_GROUP" "$ROOT_DEVICE" 
    # create the volumes with specific size
    lvcreate -L "$ROOT_SIZE"  "$VOL_GROUP" -n ArchRoot 
    lvcreate -L "$HOME_SIZE" "$VOL_GROUP" -n ArchHome 
    # insert the vol group module
    modprobe dm_mod
    # activate the vol groups
    vgchange -ay
    # format the volumes
    mkfs.ext4 /dev/"$VOL_GROUP"/ArchRoot
    mkfs.ext4 /dev/"$VOL_GROUP"/ArchHome
    # mount the volumes
    mount /dev/"$VOL_GROUP"/ArchRoot /mnt
    mkdir /mnt/home
    mount /dev/"$VOL_GROUP"/ArchHome /mnt/home
    # mount the EFI partitions
    mkdir /mnt/boot && mkdir /mnt/boot/efi
    mount /dev/sda1 /mnt/boot/efi
    echo "LVs created and mounted. Press any key."; read empty;
}

lv_create
