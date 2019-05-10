#!/bin/sh
BOOTDRIVE=`fdisk -l | grep sd | awk '{ print $2 }'| sed 's/://' |head -1`
TZ="Europe/Moscow"

LOCALEGEN1="en_US.UTF-8 UTF-8"
LOCALEGEN2="ru_RU.UTF-8 UTF-8"
LANG1=`echo $LOCALEGEN1 | awk '{ print $1 }'`
TIMESTAMP=`date -u +%d%m%y_%H%M%S`
HOSTNAME1="dpimp52s"
echo "Link /usr/share/zoneinfo/$TZ to /etc/localtime..."
ln -sf /usr/share/zoneinfo/$TZ /etc/localtime
echo "Set the Hardware Clock from the System Clock..."
hwclock --systohc
echo "set up locales" $LOCALEGEN1 $LOCALEGEN2
echo "saving locale.gen to locale.gen.org"
cp /etc/locale.gen /etc/locale.gen.org.$TIMESTAMP
echo "$LOCALEGEN1" >/etc/locale.gen
echo "$LOCALEGEN2" >>/etc/locale.gen
locale-gen
echo "set up locale in /etc/locale.conf"
echo "LANG=$LANG1" >/etc/locale.conf
echo "start network config, based on DHCP"
echo "setting hostname"
echo $HOSTNAME1 >/etc/hostname 
echo "processed /etc/hosts"
cp /etc/hosts /etc/hosts.org.$TIMESTAMP
rm /etc/hosts 
echo "127.0.0.1	localhost" >/etc/hosts
echo "::1		localhost" >>/etc/hosts
echo "127.0.1.1	$HOSTNAME1.localdomain	$HOSTNAME1" >>/etc/hosts
echo "re-create initramfs..."
mkinitcpio -p linux
echo "set up root password"
passwd
pacman -S --noconfirm grub
grub-install --target=i386-pc $BOOTDRIVE
grub-mkconfig -o /boot/grub/grub.cfg
echo "enable dhcpcd..."
systemctl enable dhcpcd
echo "enable sshd..."
pacman -S --noconfirm openssh
sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/g" /etc/ssh/sshd_config
systemctl enable sshd
