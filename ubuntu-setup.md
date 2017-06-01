
# Mount options

* atime - change file access time always
* relatime - change access time only if:
  * the modified time (mtime) or change time status (ctime) of a file is newer than the last access time (atime).
  * the access time (atime) is older than a defined interval (1 day by default on a RHEL system).
* noatime - dont write it (better for ssd) implies nodiratime

# Btrfs config

Possible mount options
https://wiki.debian.org/SSDOptimization
```
ssd,noatime,compress=lzo

#Note "discard" may cause ssd to stuck
```
NOTE: You can add compression to existing Btrfs file systems at any time, just add the option when mounting and do a defragment to apply compression to existing data.

```
sudo btrfs fi defragment -r -clzo /
```


# F2FS installation
Does not work as expected even in VirualBox

## Partitioning

* Fist partition for grub must be in ext* format (size about 128M) mount it as /boot
* Second partition for f2fs system (do not format it)
* Third partition with a little less size than previous for system installation

Make normal install to third partition, reboot and add packages for f2fs.

```
sudo apt-get update && sudo apt-get install f2fs-tools

#Tell initramfs to load the F2FS module at boot (rather than on demand)
sudo su
echo f2fs >> /etc/initramfs-tools/modules
update-initramfs -u
```

If using F2FS as your root partition, you will need to add 
the following module to the MODULES line in your /etc/mkinitcpio.conf

Now you can reboot and create f2fs on first partition
```
sudo mkfs.f2fs /dev/sda2
#After this create mount folders
sudo mkdir /mnt/f2fs
```

Reboot as root in read only/recovery mode
```
mount /dev/sda1 /mnt/f2fs
```

Copy all your files
```
# As better alternative to: cp -a 
rsync -aAXv --exclude={"/boot/*","/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} / /mnt/f2fs
```

Set drive to your fstab at f2fs partition (boot partition <pass> must be 2 for root is 1)
```
UUID=UUID-OF-/dev/sda1 /    f2fs    errors=remount-ro,noatime     0    1
```

```
#Alternative options (look like not need it - it is all default)
#UUID=UUID-OF-/dev/sda1 /    f2fs    rw,relatime,background_gc=on,user_xattr,acl,active_logs=6    0    0
```

Setup chroot for grub update
```
mount /dev/sda1 /mnt/f2fs/boot

mount --bind /dev /mnt/f2fs/dev
mount --bind /proc /mnt/f2fs/proc
mount --bind /sys /mnt/f2fs/sys
chroot /mnt/f2fs

update-grub
```

Now you can reboot, remove /dev/sda3 partition and run update-grub again


VBoxManage convertfromraw --format VDI [filename].img [filename].vdi
VBoxManage clonehd --format RAW [filename].vdi [filename].img

