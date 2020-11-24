# DARCHI    Dave's Arch Linux Installer

This is just a personal script, very very simple, to install Arch Linux after
booting the archiso ISO image.

You can download it to your booted archiso image like this:

`curl -O https://raw.githubusercontent.com/deepbsd/darchi/master/darchi.sh`

You can use *cfdisk* for editing the partition table.  *Cfdisk* seems to
work just fine for me when editing GPT disks as well as MBR disks.  
Or follow the on-screen promptings that ask how big you want the various
partitions.  Darchi.sh is more interactive than Farchi.sh.  When you run
darchi.sh, you get a menu system where you can install an Arch system to
LVM or to regular partitions, using either an MBR or GPT disktable.  (The
system simply looks for a directory which could only exist in an EFI system:
`/sys/firmware/efi`; if this exists, you are running an EFI system. Otherwise
you are running an MBR system.)

The script makes a number of assumptions and is not as flexible as other
tools.  For example, it assumes you'll want to edit your partitions.  You
can install Xorg, and it installs the cinnamon desktop by default.  You
can edit the script if you like to install your desired desktop and
utilities.  The script is about 350 lines currently.  Feel free to use it
and edit it to your taste.  

There is also a post\_install.sh file in the repo.  This will copy files
and directories that you normally have in your home directory from a host
on your network to your newly installed home directory. For example, you
could put your Pictures and Music folders in the directories to be
copied.  I include a lot fo desktop settings and everyday folders.  I
copy my public\_html and bin and .vim and a bunch of directories and
files into my new home directory.  It helps when setting up a new
desktop.  I still have to configure cinnamon quite a bit by hand, apply
themes and change icons, for example, but at least the themes and icons
and so forth are already installed.

Just fetch the script from my git page and run it after booting the archiso iso
image.

Nov 13 2020 -- I've been working on adding LVM to the darchi.sh script.  It works fine in 
vbox, but you have to set the sizes by hand.  I still have to figure a way to programmatically
set the sizes...

## The FARCHI script

I also created a script called farchi.sh for "Fast ARCH Installer".

With this script you type in the installation variables at the top of the script.
You'll need to know things like the device names of your installation partitions and
hostname, your video driver, timezone, and then edit the BASIC\_X and EXTRA\_X arrays in bash to
include your desktop selections and preferences. Also, if you need wifi drivers, 
you'll need to edit that variable.
