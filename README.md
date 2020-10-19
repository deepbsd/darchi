# DARCHI    Dave's Arch Linux Installer

This is just a personal script, very very simple, to install Arch Linux after
booting the archiso ISO image.

You can download it to your booted archiso image like this:
`curl -OL https://raw.githubusercontent.com/deepbsd/darchi/arch_install.sh`

It depends on cfdisk for editing the partition table.  Cfdisk seems to
work just fine for me when editing GPT disks as well as MBR disks.  

The script makes a number of assumptions and is not as flexible as other
tools.  For example, it assumes you'll want to edit your partitions.  You
can install Xorg, and it installs the cinnamon desktop by default.  You
can edit the script if you like to install your desired desktop.  The
script is about 350 lines currently.  There are a bunch of comments at
the back that I haven't deleted yet.  Eventually I will.  Anyway, feel
free to use it and edit it to your taste.  

There is also a post\_install.sh file in the repo.  This will copy files
and directories that you normally have in your home directory from a host
on your network to your newly installed home directory, such as your
Music and Picture folders for example.  For me, I copy my public\_html
and bin and .vim and a bunch of directories and files into my new home
directory.  And then it proceeds to customize my new desktop for me.  It
helps when setting up a new desktop.  I still have to configure cinnamon
quite a bit by hand, but at least the themes and icons and so forth are
already installed.

Just fetch the script from my git page and run it after booting the archiso iso
image.
