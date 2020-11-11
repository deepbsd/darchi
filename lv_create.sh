#!/usr/bin/env bash

IN_DEVICE=/dev/sda
EFI_DEVICE=/dev/sda1
SWAP_DEVICE=/dev/sda2
ROOT_DEVICE=/dev/sda3
#HOME_DEVICE=/dev/sda4
VOL_GROUP=arch_vg
LV_ROOT="ArchRoot"
LV_HOME="ArchHome"
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
    mkfs.fat -F32 "$EFI_DEVICE"
    # Format SWAP 
    mkswap "$SWAP_DEVICE"
    swapon "$SWAP_DEVICE"
    # create the physical volumes
    pvcreate "$ROOT_DEVICE"
    # create the volume group
    vgcreate "$VOL_GROUP" "$ROOT_DEVICE" 
    
    # You can extend with 'vgextend' to other devices too

    # create the volumes with specific size
    lvcreate -L "$ROOT_SIZE" "$VOL_GROUP" -n "$LV_ROOT"
    lvcreate -l 100%FREE  "$VOL_GROUP" -n "$LV_HOME"
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
    mount /dev/"$VOL_GROUP"/"$LV_ROOT" /mnt/home
    # mount the EFI partitions
    mkdir /mnt/boot && mkdir /mnt/boot/efi
    mount /dev/sda1 /mnt/boot/efi
    echo "LVs created and mounted. Press any key."; read empty;
}

lv_create
