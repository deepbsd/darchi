# DARCHI    Dave's Arch Linux Installer

This started as just a personal script, very very simple way to install 
Arch Linux after booting the archiso ISO image.  

You can download the script to your booted archiso image like this:

`curl -O https://raw.githubusercontent.com/deepbsd/darchi/master/darchi.sh`

## Disk Partitioning

You could use *cfdisk* for editing the partition table.  *Cfdisk* seems to
work just fine for me when editing GPT disks as well as MBR disks.  
Or instead follow the on-screen promptings that ask how big you want the various
partitions.  Darchi.sh is more interactive than Farchi.sh.  When you run
darchi.sh, you get a menu system where you can install an Arch system to
LVM or to regular partitions, using either an MBR or GPT disktable.  (The
system simply looks for a directory which could only exist in an EFI system:
`/sys/firmware/efi`; if this exists, you are running an EFI system. Otherwise
you are running an MBR system.)

By default you get:  1) 512M boot or efi partition
                     2) up to 100G in your root partiton
                     3) up to 2.5x your RAM size as swap
                     4) rest of the disk for your $HOME

## Desktop Choices

The script makes a number of assumptions and is not as flexible as other tools.  
You can install Xorg or not, and it installs the cinnamon desktop by default.  You can 
include other desktop environments if you want.  But it's BASH, so you can install
whatever you want!  

Please feel free to edit the script to install your desired desktop and utilities.  
The script is about 650 lines currently.  Feel free to use it and edit it to
your taste.  

## Post Install Process

There is also a post\_install.sh file in the repo.  This will copy files
and directories that you normally have in your home directory from a host
on your network to your newly installed home directory. For example, you
could put your Pictures and Music folders in the directories to be
copied.  I include a lot fo desktop settings and everyday folders. I have 
a separate repo just for all of my dotfiles (dot directories too), for example.  
I copy my public\_html and bin and .vim and a bunch of directories and
files into my new home directory.  It helps when setting up a new
desktop.  I still have to configure cinnamon quite a bit by hand, apply
themes and change icons, for example, but at least the themes and icons
and so forth are already installed.

Just fetch the script from my github page and run it after booting the archiso iso
image.

## The FARCHI Script

Farchi has its own repo now.  The version of the Farchi script in this repo is
probably not up to date.

I also created a script called farchi.sh for "Fast ARCH Installer".  This was supposed
to be a bone simple script that you could edit and get installed fast with.  It's longer
now, since I tend to like LVM.  But I have a mix of both EFI and non-EFI machines, so 
I've had to build some intelligence into the script at the expense of more lines of code!

As time has gone by, I have fewer and fewer non-EFI machines.  I have given most of these
away to friends or family.  I may have to set default to GPT disklabel by default.

## Default Variable Values

With this script you set the installation variables at the top of the script.
You'll need to know things like the device names of your installation partitions and
hostname, your video driver, timezone, and then edit the BASIC\_X and EXTRA\_X arrays in bash to
include your desktop selections and preferences. Also, if you need wifi drivers, 
you'll need to edit that variable.  Also, the script can figure out whether you have an 
EFI or system or not, but you need to decide whether you want to use LVM or not.

You can download it to your booted archiso image like this:

`curl -O https://raw.githubusercontent.com/deepbsd/darchi/master/farchi.sh`

## Next Steps

I spent the last few days learning AWK. With that tool, I can calculate disk and memory sizes
from a running linux system.  With that data, I can programmatically create partitions based on
whether someone wants the ability to hibernate a system (which I tend to like) by creating a swap
partition that is 2.5 times the size of the available RAM.  Also, I tend to like a larger root partition
so I don't have to keep cleaning out the package cache.  Or if I accumulate a few extra kernels in 
/boot, I don't have to worry about overflowing the root partition.  For that reason, I tend to like
root partitions of around 100GBs, and home partitions that contain the rest of the system.  You can
easily install a linux system on a 10GB root partition, and most distros create around a 20-50GB 
root partition by default.  If you're using LVM you can easily resize the LVs inside the PV (Physical
Volume), but these days, your disk will probably be at least a half terabyte.  My music and video libraries
do not take up more than 400GB, so why not give the root partition all of 100GB?  400GB for my home
partition is plenty.  And if I need more, I can add other physical volumes to the Volume Group
and mount them as required.

Anyway, I want to implement auto partitioning according to four schemes:

1) Partition with LVM and with hibernate
2) Partition without LVM and with hibernate
3) Partition with LVM and without hibernate
4) Partition without LVM and without hibernate

After that, I think I can begin to use curses-based library so the graphical installation for darchi.sh
is more attractive and easier for newer users.

## Concern

Right now I have two separate methods for disk partitioning, one called lv\_create() and disk\_partition() I think.
It's not called that but I can't think of the name right now.  Anyway, I should consolodate all that code
so I'm not duplicating my efforts.  There should be one pipe that everything goes through.  Only thing different
is making PVs, LVs, and VGs.  That's going to be different from just using physical partitions alone.  

I should just consolodate a lot of that code!
