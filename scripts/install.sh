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

# copy kernel debs 
cp /data/kernel/*.deb ${MP}/var/tmp/

# apt sources
cat << EOF > $MP/etc/apt/sources.list
deb ${MIRROR} ${RELEASE} main contrib non-free
deb ${MIRROR} ${RELEASE}-security main contrib non-free
deb ${MIRROR} ${RELEASE}-updates main contrib non-free
EOF

# hostname
echo ${HOST_NAME} > ${MP}/etc/hostname
sed -i 's/127\.0\.0\.1.*$/& '$HOST_NAME'/' ${MP}/etc/hosts

# fstab
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

# crypttab
cat << EOF > ${MP}/etc/crypttab
# <target name> <source device> <key file> <options>
$CRMAP $CRDEV none luks
EOF

# enable initramfs cryptsetup unconditionally
echo "CRYPTSETUP=y" >> ${MP}/etc/cryptsetup-initramfs/conf-hook

# initramfs modules
cat << EOF > ${MP}/etc/initramfs-tools/modules
# List of modules that you want to include in your initramfs.
# They will be loaded at boot time in the order below.
#
# Syntax:  module_name [args ...]
#
# You must run update-initramfs(8) to effect this change.
#
omaplfb
sd_mod
omap_hsmmc
mmc_block
omap_wdt
twl4030_wdt
leds_lp5523
EOF

# update-initramfs hook to update u-boot images
mkdir -p ${MP}/etc/initramfs/post-update.d
cat << EOF > ${MP}/etc/initramfs/post-update.d/update-u-boot
#!/bin/sh
#
# update-u-boot update-initramfs hook to update u-boot images
# Distributable under the terms of the GNU GPL version 3.
KERNELRELEASE=\$1
INITRAMFS=\$2
# Create uInitrd under /boot
mkimage -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n initramfs -d \$INITRAMFS /boot/uInitrd-\$KERNELRELEASE
EOF
chmod +x ${MP}/etc/initramfs/post-update.d/update-u-boot

# initramfs script to turn on keyboard leds
mkdir -p ${MP}/etc/initramfs-tools/scripts/local-top/
cat << EOF > ${MP}/etc/initramfs-tools/scripts/local-top/kbdled
#!/bin/sh
PREREQ=""
prereqs()
{
        echo "\$PREREQ"
}
case \$1 in
prereqs)
        prereqs
        exit 0
        ;;
esac
for n in 1 2 3 4 5 6
do
        echo 50 > /sys/class/leds/lp5523\:kb\${n}/brightness
done
exit 0
EOF
chmod +x ${MP}/etc/initramfs-tools/scripts/local-top/kbdled

# unset trap on exit to avid cleanup
# trap - 0
