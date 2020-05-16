#!/bin/bash
# prepare sd card from images

CRMAP=crypt_sd
#CPASS=test123

usage(){
	echo "usage: $0 /dev/<device>"
	exit
}

abort(){
	echo "-err: $1" >&2
        exit 1

}

[[  $# -ne 1 ]] && usage

[[ $(id -u) -eq 0 ]] || abort "must be root"

D=$1

[[ -b ${D} ]] || abort "${D} is not a block device"

for a in $(seq 2);
do
	[[ -b ${D}${a} ]] || abort "${D}${a} is not a block device, sd must have 2 partitions"
done

for a in boot root;
do
	[[ -e /data/${a}.img ]] || abort "/data/${a}.img does not exist"
done

cryptsetup status ${CRMAP} && abort "container is active, quitting"

# dangerouus stuff starts here
# interactive
cryptsetup luksFormat ${D}2 || abort "luksFormat failed"
# unattended
# echo -n "$CPASS" | cryptsetup -q luksFormat ${D}2 -
# or use pre-generated key

cryptsetup luksOpen ${D}2 ${CRMAP} || abort "luksOpen failed"
# unattended
# echo -n "$CPASS" | cryptsetup luksOpen ${D}2 ${CRMAP} -
# or use pre-generated key

dd if=/data/root.img of=/dev/mapper/${CRMAP} status=progress
e2fsck -f /dev/mapper/${CRMAP}
resize2fs -p /dev/mapper/${CRMAP}
e2fsck -f /dev/mapper/${CRMAP}
cryptsetup luksClose ${CRMAP}

dd if=/dev/urandom of=${D}1 bs=10M status=progress
dd if=/data/boot.img of=${D}1 status=progress
e2fsck -f ${D}1
resize2fs -p ${D}1
e2fsck -f ${D}1
