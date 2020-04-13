#!/bin/bash

# guess if we are in privileged mode
if [[ ! -e /dev/mem ]]; then
	echo "-err: container not run im priveleged mode"
	exit
fi
# if you want to be sure, do something for real, like
# ip link add dummy0 type dummy
# but it's an overkill

if [[ ! -e /data/root.img ]]; then
	dd if=/dev/zero of=/data/root.img bs=1M count=2048 status=progress
	mkfs.ext4 /data/root.img
fi

if [[ ! -e /data/boot.img ]]; then
	dd if=/dev/zero of=/data/boot.img bs=1M count=300 status=progress
	mkfs.ext4 /data/boot.img
fi

[[ -e /dev/loop0 ]] || mknod /dev/loop0 b 7 0
[[ -e /dev/loop1 ]] || mknod /dev/loop1 b 7 1

mount /data/root.img /mnt/
mkdir -p /mnt/boot
mount /data/boot.img /mnt/boot

losetup -D
umount /mnt/boot
umount /mnt/
