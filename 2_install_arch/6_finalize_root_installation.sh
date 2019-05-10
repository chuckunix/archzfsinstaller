#!/bin/sh
CWD=/root
RPOOL=zroot
DRIVE=`fdisk -l | grep sd | awk '{ print $2 }'| sed 's/://' | head -n 1`
EFIPART=`fdisk -l | grep sd | grep EFI | awk '{ print $1 }'| head -n 1`
echo $DRIVE
ARCHZFS=`cat /etc/pacman.conf | grep archzfs|wc -l`
ZFSINST=`pacman -Q | grep zfs-dkms | wc -l`
SPLINST=`pacman -Q | grep spl-dkms | wc -l`
if [ $ARCHZFS == 0 ]
	then
	echo "[archzfs]" >> /etc/pacman.conf
	echo 'Server = http://archzfs.com/$repo/$arch' >> /etc/pacman.conf
fi
pacman-key --lsign-key F75D9D76
pacman -Syyu
if [ $SPLINST == 0 ] || [ $ZFSINST == 0 ]; then
	pacman -S  --noconfirm linux-headers
	pacman -S  --noconfirm spl-dkms
	pacman -S  --noconfirm zfs-dkms
fi
pacman -S  --noconfirm git sudo fakeroot
echo "nobody ALL=(ALL) NOPASSWD: /usr/bin/pacman" >>/etc/sudoers
mkdir /home/build
chgrp nobody /home/build
chmod g+ws /home/build
setfacl -m u::rwx,g::rwx /home/build
cd /home/build
sudo -u nobody git clone https://aur.archlinux.org/mkinitcpio-sd-zfs.git
cd mkinitcpio-sd-zfs/
sudo -u nobody makepkg
sudo -u nobody makepkg --noconfirm -i
cd ..
pacman -S --noconfirm python-pip
pacman -S --noconfirm python-click
sudo -u nobody git clone https://aur.archlinux.org/python-pyzfscmds
sudo -u nobody git clone https://aur.archlinux.org/zedenv
sudo -u nobody git clone https://aur.archlinux.org/zedenv-grub
cd ./python-pyzfscmds
sudo -u nobody makepkg --noconfirm -i
cd ../zedenv
sudo -u nobody makepkg --noconfirm -i
cd ../zedenv-grub
sudo -u nobody makepkg --noconfirm -i

##HOOKS should be set by right way:
sed -i "s/block filesystems keyboard fsck/block keyboard systemd sd-zfs filesystems/g" /etc/mkinitcpio.conf
#zfs driver should be loaded __after__ keyboard on  ramdisk image!!
# Use INSTALLED_KERNEL for avoiding error - if the kernel version != installed via pacstrap
INSTALLED_KERNEL=`ls /lib/modules | grep arch | grep ARCH`
mkinitcpio -k $INSTALLED_KERNEL  -g /boot/initramfs-linux.img
pacman -S --noconfirm grub
pacman -S --noconfirm parted
if [ -d /boot/efi ]
	then
	echo "/boot/efi exists.."
	else	
	mkdir /boot/efi
fi
##assume the sda1 contain  the Windows EFI boot partition;
if [ -z $EFIPART ] 
then
	echo "EFI partition not found, exiting.."
	exit
else
	mount $EFIPART /boot/efi
	if	[ -d /boot/efi/EFI ]
	then
		echo "efi/EFI exists on  $EFIPART. Looks good"
	else
		echo "probably incorrect EFI partition found. Check it manually"
	fi
fi
	if 	[ -d /boot/efi/EFI/grub ]
	then
	rm -r /boot/efi/EFI/grub
	fi
pacman --noconfirm -S  arch-install-scripts efibootmgr dhcpcd openssh 
echo "enable dhcpcd..."
systemctl enable dhcpcd
echo "enable sshd with root access"
sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/g" /etc/ssh/sshd_config
systemctl enable sshd
echo "set up "root" as default passwd for root"
echo -e "root\nroot" | passwd
grub-install --efi-directory=/boot/efi --boot-directory=/boot/efi/EFI --bootloader-id=grub
##add to  /etc/modules-load.d/vfat.conf
###
#vfat
#nls_cp437
#nls_iso8859-1
patch -p1 /etc/grub.d/10_linux < $CWD/10_linux_sd-zfs.patch 
patch -p1 /etc/grub.d/20_linux_xen < $CWD/20_linux_xen_sd_zfs.patch 
patch -p1 /etc/grub.d/05_zfs_linux.py < $CWD/05_zfs_linux.py_zedenv_grub.patch
mkdir /boot/grub
zfs create -o canmount=off zroot/boot
zfs create -o mountpoint=legacy zroot/boot/grub
mount -t zfs zroot/boot/grub /boot/grub
mount -t zfs zroot/data/home /home
zedenv set org.zedenv.grub:bootonzfs=yes
zedenv set org.zedenv.grub:boot=/boot/grub
zedenv set org.zedenv:bootloader=grub

echo "add $EFIPART and /boot/grub " to /dev/fstab
genfstab  / | grep $EFIPART >> /etc/fstab
genfstab  / | grep zroot/boot/grub >> /etc/fstab
genfstab  / | grep zroot/data/home >> /etc/fstab
cat /root/symlink_stage6.run | sh
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
ZPOOL_VDEV_NAME_PATH=1 grub-mkconfig -o /boot/grub/grub.cfg

zedenv create new_boot
zedenv activate new_boot
umount $EFIPART
