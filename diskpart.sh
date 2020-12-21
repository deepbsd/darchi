#!/usr/bin/env bash

##  This is a prototype for getting the sizes of the available disks and memory
##  and then automatically generating disk partition sizes that will accommodate
##  a new Linux installation on that disk

#  Basic idea:  1) list disks with sizes  2) list available memory size  3) do you want to hibernate?
#  4) do you want LVM?    5) calculate swap

RAM=()
#DISKS=( sdb 400 )
DISKS=()
declare -A disk_hash
hibernate='n'

get_disks(){
   for line in $(lsblk | grep disk | awk '{ printf "%s:%s ",  $1, $4 }'); do
        disk=$(echo "$line" | cut -f1 -d:)
        capacity=$(echo "$line" | cut -f2 -d:)
        disk_hash[name]="$disk"  
        disk_hash[capacity]="$capacity" 
        echo "part: ${disk_hash[name]}  size: ${disk_hash[capacity]}"
        DISKS+=( "$disk_hash" )
   done

   #for dsk in "${DISKS[@]}"; do
   #     echo "$dsk"
   #done

   echo "DISKS:  ${DISKS[0][name]}"

   #max=${#DISKS[@]}
   #for ((n=0;n<$max;n+=2)); do
   #     printf "%s\t\t%s\n" ${DISKS[$n]} ${DISKS[(($n+1))]%.*}
   #done
}

get_swap(){
    ram=$(free | grep Mem | awk '{print ($2/1000000)}')
    ram=${ram%.*}
    half=$(echo "scale=1;$ram*0.5" | bc)
    half=${half%.*}
    one_pt_five=$(echo "scale=1;$ram*1.5" | bc)
    one_pt_five=${one_pt_five%.*}
    case 1 in
        $(( $ram <= 2 )) ) [[ "$hibernate" =~ [yY] ]] && swap=$((ram*3)) || swap=$((ram*2)) ;;
        $(( $ram <= 8 )) ) [[ "$hibernate" =~ [yY] ]] && swap=$((ram*2)) || swap=$((ram)) ;;
        $(( $ram <= 16 )) ) [[ "$hibernate" =~ [yY] ]] && swap=$((ram*2)) || swap=$((ram)) ;;
        $(( $ram <= 32 )) ) [[ "$hibernate" =~ [yY] ]] && swap=$((ram*2)) || swap=$((ram)) ;;
        $(( $ram > 32 )) ) [[ "$hibernate" =~ [yY] ]] && swap=$((one_pt_five)) || swap=$((half))  ;;
    esac
    echo "$swap"
}

get_root(){
    if [[ ${#DISKS[@]} -le 2 ]]; then
        if [[ $(get_disks | awk '{print $2}') -le 30 ]]; then
            size=12
        elif [[ $(get_disks | awk '{print $2}') -le 50 ]]; then
            size=20
        elif [[ $(get_disks | awk '{print $2}') -le 100 ]]; then
            size=75
        else
            size=100
        fi
        echo "${size}"
    else
        ## Still gotta work on this one...
        echo "Which disk? "
        max=${#DISKS[@]}
        for ((n=0;n<$max;n+=2)); do
             printf "%s\t\t%s\n" ${DISKS[$n]} ${DISKS[(($n+1))]%.*}
        done
        read dsk
        echo "${DISKS[${dsk}]}"
    fi
}

echo "do you want to hibernate? "; read hibernate
get_disks 
#get_swap 
#get_root

