#!/usr/bin/env bash

##  This is a prototype for getting the sizes of the available disks and memory
##  and then automatically generating disk partition sizes that will accommodate
##  a new Linux installation on that disk

#  Basic idea:  1) list disks with sizes  2) list available memory size  3) do you want to hibernate?
#  4) do you want LVM?    5) calculate swap

RAM=()
DISKS=()

get_disks(){
   for d in $(lsblk | grep disk | awk '{printf "%s\n%s\n",$1,$4}'); do
        DISKS+=($d)
   done

   max=${#DISKS[@]}
   for ((n=0;n<$max;n+=2)); do
        printf "%s\t\t%s\n" "DEVICE" "SIZE"
        printf "%s\t\t%s\n" ${DISKS[$n]} ${DISKS[(($n+1))]}
   done
}

get_swap(){
    ram=$(free | grep Mem | awk '{print ($2/1000000)*1.4}')
    swap=${ram%.*}
    echo "swap:  ${swap}G"
}

calculate_swap(){
echo
}

get_disks
get_swap
