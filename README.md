# docker-devuan-wrk

```
$ docker run -it --rm --privileged  devuan-wrk
```

install:
```
# /data/install.sh
```

Insert SD card.

dmesg:
```
sd 4:0:0:0: [sdb] Attached SCSI removable disk
```

fill sd card with random data:
```
# dd if=/dev/urandom of=/dev/sdb bs=100M status=progress
```

patrtition sd card (crerate 300M first and the rest - second partition):
```
# cfdisk /dev/sdb

# fdisk -l /dev/sdb
Disk /dev/sdb: 7.4 GiB, 7948206080 bytes, 15523840 sectors
...
Device     Boot  Start      End  Sectors  Size Id Type
/dev/sdb1         2048   616447   614400  300M 83 Linux
/dev/sdb2       616448 15523839 14907392  7.1G 83 Linux
```
Format LUKS crypto-container on the second patrition and open it:
```
# cryptsetup luksFormat /dev/sdb2

# cryptsetup luksOpen /dev/sdb2 crypt_sd
```

dd images to respected partitions and expand filesystems:
```
# dd if=/data/root.img of=/dev/mapper/crypt_sd status=progress

# e2fsck -f /dev/mapper/crypt_sd

# resize2fs -p /dev/mapper/crypt_sd

# e2fsck -f /dev/mapper/crypt_sd

# dd if=/data/boot.img of=/dev/sdb1 status=progress

# e2fsck -f /dev/sdb1

# resize2fs -p /dev/sdb1

# e2fsck -f /dev/sdb1
```
