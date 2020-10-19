# DARCHI    Dave's Arch Linux Installer

This is just a personal script, very very simple, to install Arch Linux after
booting the archiso ISO image.

You can download it to your booted archiso image like this:

`curl -OL https://raw.githubusercontent.com/deepbsd/darchi/arch_install.sh`

It depends on *cfdisk* for editing the partition table.  *Cfdisk* seems to
work just fine for me when editing GPT disks as well as MBR disks.  

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
