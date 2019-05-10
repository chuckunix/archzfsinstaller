#!/bin/sh
#echo  put"
#First "put on console first: 'systemctl start sshd; passwd'"
#Then, copy 1_*.sh and 2_*.sh into /root on Arch liveCD":
#cp [1-2]_* root@<livecd_IP>:/root/
LOC=ru #set keyboard locale
LOCFILE="/usr/share/kbd/keymaps/**/$LOC.map.gz"
if [ -s $LOCFILE ]
	then
	loadkeys $LOC
fi
#check EFI mode:
if [ -s "/sys/firmware/efi/efivars" ]
	then 
	EFI=true; echo "system contain EFI"
	else
	EFI=false; echo "system contain old-style MBR"
fi
echo "check Internet connection.."

while ! ping -c1 archlinux.org &>/dev/null
	do echo "Ping Fail...Exiting"
	exit
done
echo "set up NTP time/date.."
timedatectl set-ntp true

DRIVE=`fdisk -l | grep sd | awk '{ print $2 }'| sed 's/://' | head -n 1`
echo "Disk prepare, found following device:" $DRIVE

if [ $DRIVE ]
	then
	echo "running  $DRIVE"
	else
	echo "not found anything, exiting" 
fi

read -e -p "Use $DRIVE for installation  ? [Y/n] " YN
if [[ $YN == "y" || $YN == "Y" ]]
	then 
	echo "selected $DRIVE" ; INSTDRIVE=$DRIVE
	else
	echo "exiting..." ;  exit
	fi 
parted $INSTDRIVE mktable msdos
DISKSIZE=`parted $INSTDRIVE unit s print | grep $INSTDRIVE | awk '{ print $3 }'|sed 's/s//'`
SWAPSIZE=`echo "512000000/512"|bc` #set swapsize=512MB
ROOTSIZE=`echo $DISKSIZE-$SWAPSIZE|bc`
ALIGN=2048 #alignment set to 2048
echo "fulldisk=$DISKSIZE, root=$ROOTSIZE, swap=$SWAPSIZE (in sectors)"
parted $INSTDRIVE unit s mkpart primary ext4 $ALIGN $ROOTSIZE
parted $INSTDRIVE unit s print
parted $INSTDRIVE -a none unit s mkpart primary linux-swap `echo $ROOTSIZE+1|bc` 100%
ROOTFS="$INSTDRIVE"1
SWAPFS="$INSTDRIVE"2
echo root as $ROOTFS, swap as $SWAPFS

mkfs.ext4 -F $ROOTFS
mkswap $SWAPFS
mount $ROOTFS /mnt

echo "mounted.... `mount | grep $ROOTFS`"
echo "Downloading Packages.It take time"
pacstrap /mnt base

echo "Generating fstab:"
genfstab -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab
echo "Chrooting:..."
cp /root/2_finalize_installation.sh /mnt/root
arch-chroot /mnt /root/2_finalize_installation.sh
echo "Installation finished. Umounting /mnt.."
umount  -R /mnt
echo Remove installation media: "Press Enter key to reboot "
read
echo b > /proc/sysrq-trigger
