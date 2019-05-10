#!/bin/sh
RPOOL=zroot
PARTNAME=ArchLinux@ZFSboot
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
################################Comment line below if you use real system
#parted $INSTDRIVE mklabel gpt ###################COMMENT THIS!!!###########
parted $INSTDRIVE unit s print
DISKSIZE=`parted $INSTDRIVE unit s print | grep $INSTDRIVE | awk '{ print $3 }'|
sed 's/s//'`
FREESPACE=`parted $INSTDRIVE unit s print free | grep Free | tail -1`
STARTOFFSET=`echo $FREESPACE | awk '{ print $1 }'`
ENDOFFSET=`echo $FREESPACE | awk '{ print $2 }'`
echo "disk $INSTDRIVE, $DISKSIZE sectors size, freespace start is $STARTOFFSET, ends in $ENDOFFSET"
parted $INSTDRIVE unit s mkpart primary $STARTOFFSET $ENDOFFSET
PARTNUM=`parted $INSTDRIVE unit s print | grep $STARTOFFSET | awk '{ print $1 }'`
echo "created  partition $PARTNUM"
parted -s $INSTDRIVE name $PARTNUM $PARTNAME
echo "Sleep 5 seconds: await updates in /dev/disk/by-id"; sleep 5
#search a independent disk name based on WWN
DISKSHORT=`echo $INSTDRIVE | sed 's/[/]dev[/]//'`
echo $DISKSHORT
#comment or uncomment wwn device type (bare metal or ata (virtual hw)
POOLDEV=`ls -l /dev/disk/by-id/ | grep $DISKSHORT | grep wwn | grep $DISKSHORT$PARTNUM | awk '{ print $9 }'`
#POOLDEV=`ls -l /dev/disk/by-id/ | grep $DISKSHORT | grep ata | grep $DISKSHORT$PARTNUM | awk '{ print $9 }'`
echo /dev/disk/by-id/$POOLDEV is device for ZFS pool, original named as $INSTDRIVE$PARTNUM for old notation
read -e -p "Use /dev/disk/by-id/$POOLDEV  for installation  ? [Y/n] " YN
if [[ $YN == "y" || $YN == "Y" ]]
        then 
        echo "selected /dev/disk/by-id/$POOLDEV" ; 
       	zpool create -f $RPOOL /dev/disk/by-id/$POOLDEV 
	zpool status
	zpool list
	else
        echo "exiting..." ;  exit
        fi 
echo "create zfs  datasets..."
zfs create -o mountpoint=none $RPOOL/data
zfs create -o mountpoint=none $RPOOL/ROOT
zfs create -o compression=lz4 -o mountpoint=/ $RPOOL/ROOT/default
#zfs create $RPOOL/ROOT/default/var
zfs create -o compression=lz4 -o mountpoint=/home $RPOOL/data/home
echo "umount all zfs filesytems..."
zfs unmount -a
echo "set mountpoints.."
zfs set mountpoint=/ $RPOOL/ROOT/default
#zfs set mountpoint=/var $RPOOL/ROOT/default/var
zfs set mountpoint=legacy $RPOOL/data/home
echo "...and  put them into /etc/fstab on livecd"
echo "$RPOOL/ROOT/default / zfs defaults,noatime 0 0" >/etc/fstab
echo "$RPOOL/data/home /home zfs defaults,noatime 0 0" >>/etc/fstab
echo "/etc/fstab: "; cat /etc/fstab ; echo '\n'
echo "set bootfs property on $RPOOL"
zpool set bootfs=$RPOOL/ROOT/default $RPOOL
echo "export pool...:"
zpool export $RPOOL
echo "and attempt to re-import them"
zpool import -d /dev/disk/by-id -R /mnt $RPOOL
zpool set cachefile=/etc/zfs/zpool.cache $RPOOL
mkdir -p /mnt/etc/zfs/
cp /etc/zfs/zpool.cache /mnt/etc/zfs/zpool.cache
#mount esp partition 
genfstab -U -p /mnt >> /mnt/etc/fstab
#comment #zroot               	/zroot  - in /etc/grub otherwise it not boot
sed -i "s/zroot /#zroot/g" /mnt/etc/fstab

zfs create -V 8G -b $(getconf PAGESIZE) \
              -o logbias=throughput -o sync=always\
              -o primarycache=metadata \
              -o com.sun:auto-snapshot=false $RPOOL/swap
mkswap -f /dev/zvol/$RPOOL/swap
swapon /dev/zvol/$RPOOL/swap
echo "/dev/zvol/$RPOOL/swap none swap discard 0 0" >>/mnt/etc/fstab
pacman-key --recv F75D9D76
pacman-key --lsign-key F75D9D76
pacstrap /mnt
cp /root/6_finalize_root_installation.sh /mnt/root
cp 10_linux_sd-zfs.patch /mnt/root
cp 20_linux_xen_sd_zfs.patch /mnt/root
cp 05_zfs_linux.py_zedenv_grub.patch /mnt/root
#next string is a hack, required for GRUB installation: /dev/wwn*_part[x]
echo "ln -s $DRIVE$PARTNUM /dev/$POOLDEV" >/mnt/root/symlink_stage6.run
arch-chroot /mnt
#arch-chroot /mnt /root/6_finalize_root_installation.sh
swapoff -a
zfs umount -a
zpool export zroot
#reboot
