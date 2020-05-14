#!/bin/bash

DEBUG=
DATA="/data"
MP="/mnt"

MIRROR=http://deb.devuan.org/merged
DEBARCH=armhf
RELEASE=beowulf
ESSENTIAL=acpid,acpi-support-base,console-common,console-setup,cryptsetup,initramfs-tools,iputils-ping,keyboard-configuration,kmod,locales,netbase,net-tools,patch,u-boot-tools,udev,vim,wget
DISPLAYSRV=xorg,xserver-xorg-video-fbdev,xserver-xorg-video-omap,xinput-calibrator
EXTRA=apt-utils,bluez,ifupdown,isc-dhcp-client,iw,man-db,mtd-utils,pm-utils,rfkill,rsyslog,ssh,whiptail,wireless-tools,wpasupplicant,${DISPLAYSRV}

BOOTDEV=/dev/mmcblk0p1
CRDEV=/dev/mmcblk0p2
CRMAP=crypt_sd
ROOTDEV=/dev/mapper/${CRMAP}
SWDEV=/dev/mmcblk1p3 # FIXME: change to /dev/zram0 after initscript is in place

HOST_NAME=n900

cleanup(){
	[[ -d ${MP}/boot ]] && umount -d -q ${MP}/boot
	[[ -d ${MP} ]] && umount -d -q ${MP}
	losetup -D # not needed, but docker, you know...
	exit
}

abort(){
	echo "-err: $1" >&2
	exit 1
}

# cleanup on trap
trap cleanup 0 1 2 15

[[ $(id -u) -eq 0 ]] || abort "must be root"
[[ -e /.dockerenv  ]] ||  abort  "must be run in docker"
# guess if we are in privileged mode
[[ -e /dev/mem ]] ||  abort  "docker container must be run in priveleged mode"
# if you want to be sure, do something for real, like
# ip link add dummy0 type dummy
# but it's an overkill

# dirty, add getopt(s) if more options
[[ "$1" = "-c" ]] && cleanup

update-binfmts --enable qemu-arm > /dev/null 2>&1 || true
update-binfmts --display qemu-arm | grep -q enable || abort "ARM executable binary format not registered"

if [[ ! -e ${DATA}/root.img ]]; then
	dd if=/dev/zero of=${DATA}/root.img bs=1M count=2048 status=progress
	mkfs.ext4 ${DATA}/root.img
fi

if [[ ! -e ${DATA}/boot.img ]]; then
	dd if=/dev/zero of=${DATA}/boot.img bs=1M count=200 status=progress
	mkfs.ext4 ${DATA}/boot.img
fi

[[ -e /dev/loop0 ]] || mknod /dev/loop0 b 7 0
[[ -e /dev/loop1 ]] || mknod /dev/loop1 b 7 1

grep -q "${MP} " /proc/mounts || mount ${DATA}/root.img ${MP}/
mkdir -p ${MP}/boot
grep -q "${MP}/boot " /proc/mounts || mount ${DATA}/boot.img ${MP}/boot

[[ "$(ls ${MP} | grep -v 'lost+found')" = "boot" ]] || abort "filesystem already contains data"

# base install
qemu-debootstrap ${DEBUG:+--verbose} --arch=${DEBARCH} --variant=minbase --include=${ESSENTIAL}${EXTRA:+,$EXTRA} ${RELEASE} ${MP} ${MIRROR}

# fix apt sources
cat << EOF > $MP/etc/etc/apt/sources.list
deb ${MIRROR} ${RELEASE} main contrib non-free
deb ${MIRROR} ${RELEASE}-security main contrib non-free
deb ${MIRROR} ${RELEASE}-updates main contrib non-free
EOF

# fix hostname
echo ${HOST_NAME} > ${MP}/etc/hostname
sed -i 's/127\.0\.0\.1.*$/& '$HOST_NAME'/' ${MP}/etc/hosts

# create fstab
cat << EOF > ${MP}/etc/fstab
# /etc/fstab: static file system information.
#
# <file system> <mount point> <type> <options> <dump> <pass>
$ROOTDEV / ext4 errors=remount-ro,noatime 0 1
$BOOTDEV /boot ext4 noatime 0 0
$SWDEV none swap sw 0 0
proc /proc proc nodev,noexec,nosuid 0 0
none /tmp tmpfs noatime 0 0
EOF

# create crypttab
cat << EOF > ${MP}/etc/crypttab
# <target name> <source device> <key file> <options>
$CRMAP $CRDEV none luks
EOF
