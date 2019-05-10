#!/bin/sh
ROOTDIR=/root
RELEASE=`uname -r`
pacman -S --noconfirm archiso
BUILD=$RELEASE-ZFS
ARCHLIVE="$ROOTDIR/$BUILD"
echo name: $BUILD , location:  $ARCHLIVE
if [ -d $ARCHLIVE ]; then rm -r $ARCHLIVE;  fi 
if [ -d $ROOTDIR/out ]; then rm -r $ROOTDIR/out; fi 
if [ -d $ROOTDIR/work ]; then rm -r $ROOTDIR/work; fi 

mkdir $ARCHLIVE
cp -r /usr/share/archiso/configs/releng/* $ARCHLIVE
echo "[archzfs]" >> $ARCHLIVE/pacman.conf
echo 'Server = http://archzfs.com/$repo/$arch' >> $ARCHLIVE/pacman.conf
echo "archzfs-linux" >> $ARCHLIVE/packages.x86_64
$ARCHLIVE/build.sh -v
