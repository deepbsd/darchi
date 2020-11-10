#!/usr/bin/env bash

IN_DEVICE=/dev/sda
EFI_DEVICE=/dev/sda1
SWAP_DEVICE=/dev/sda2
ROOT_DEVICE=/dev/sda3
HOME_DEVICE=/dev/sda4
VOL_GROUP=arch_vg
ROOT_GROUP=root_vg
HOME_GROUP=home_vg

EFI_SIZE=512M
ROOT_SIZE=14G
HOME_SIZE=14G
SWAP_SIZE=2G

lv_create(){
    # Create the physical partitions
    sgdisk -Z "$IN_DEVICE"
    sgdisk -n 1::+"$EFI_SIZE" -t 1:ef00 -c 1:EFI "$IN_DEVICE"
    sgdisk -n 2::+"$SWAP_SIZE" -t 2:8200 -c 2:SWAP "$IN_DEVICE"
    sgdisk -n 3::+"$ROOT_SIZE" -t 3:8e00 -c 3:ROOT_VOL "$IN_DEVICE"
    sgdisk -n 4 -t 4:8e00 -c 4:HOME_VOL "$IN_DEVICE"
    # Format the EFI partition
    mkfs.fat -F32 "$SWAP_DEVICE"
    # Format SWAP 
    mkswap "$SWAP_DEVICE"
    swapon "$SWAP_DEVICE"
    # create the root and home physical volumes
    pvcreate "$ROOT_DEVICE"
    pvcreate "$HOME_DEVICE"
    # create the volume groups
    #vgcreate root_vg "$ROOT_DEVICE"
    vgcreate "$VOL_GROUP" "$ROOT_DEVICE" "$HOME_DEVICE"
    # create the volumes with specific size
    lvcreate -L "$ROOT_SIZE" "$ROOT_DEVICE"
    lvcreate -L "$HOME_SIZE" "$HOME_DEVICE"
    # insert the vol group module
    modprobe dm_mod
    # activate the vol groups
    vgchange -ay
    # format the volumes
    mkfs.ext4 /dev/"$VOL_GROUP" -n "$ROOT_GROUP"
    mkfs.ext4 /dev/"$VOL_GROUP" -n "$HOME_GROUP"
    # mount the volumes
    mount /dev/root_vg/root_vg /mnt
    mkdir /mnt/home
    mount /dev/home_vg/home_vg /mnt/home
    # mount the EFI partitions
    mkdir /mnt/boot && mkdir /mnt/boot/efi
    mount /dev/sda1 /mnt/boot/efi
    echo "LVs created and mounted. Press any key."; read empty;
}

lv_create
