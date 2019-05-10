#!/bin/sh
CHECKREPO=`cat /etc/pacman.conf | grep archzfs|wc -l`
if [ $CHECKREPO == 0 ]
then
echo "[archzfs]" >>/etc/pacman.conf
echo 'Server = http://archzfs.com/$repo/$arch' >> /etc/pacman.conf
fi

EXISTZFS=`pacman -Q zfs | wc -l`
EXISTSPL=`pacman -Q spl | wc -l`
if [ $EXISTZFS != 0 ] 
then
	pacman -R --noconfirm zfs-dkms
fi
if [ $EXISTSPL != 0 ] 
then
	pacman -R --noconfirm spl-dkms
fi
pacman-key -r F75D9D76
pacman-key --lsign-key F75D9D76
pacman -Syyu
pacman -S  --noconfirm linux-headers
pacman -S  --noconfirm archzfs-dkms
/sbin/modprobe zfs
PROBEZFS=`lsmod | grep zfs |wc -l`
echo $PROBEZFS
if [ $PROBEZFS != 0 ]
	then
	echo "attempting to create test pool into /root/testpool.img"
	TESTPOOL="/root/testpool.img"
	dd if=/dev/zero of=$TESTPOOL bs=1M count=100
	zpool create TEST_POOL $TESTPOOL
	zpool status TEST_POOL
TESTPOOL_STATE=`zpool status |wc -l`
	if [ $TESTPOOL_STATE != 0 ]
	then
		echo "removing test ZFS pool"
		zpool destroy  TEST_POOL
		rm -rf $TESTPOOL
		echo "...done"
		else
		echo "something goes wrong with test pool "
	fi 	
	else
	echo "no zfs module found.. exiting"
	exit
fi
