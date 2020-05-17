# docker-devuan-wrk

Initial approach of making separate filesystem images and then dd'ing to sd card did not work quite well with crypsetup initrd hooks + docker.
We should reconsider all the process.

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

finalise sd card:
```
# /data/mksd.sh /dev/sdb
```
