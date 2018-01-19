# Packages

```
apt-get install emacs-nox mc tmux vnstat libcurl3
apt-get purge nano snapd snap-confine mdadm cryptsetup
```

After uninstall cryptsetup dudes suggest to reconfigure/install grub

```
sudo update-grub
sudo grub-install /dev/<your_device_id>
```

# Configure sensors
```
apt-get install  lm-sensors
# Now you should detect sensors
sudo sensors-detect

```
And just follow the prompts. 
Add the recommended lines to /etc/modules.

# Build tools

# Configuration 

##Journal persistence
```
mkdir /var/log/journal
systemd-tmpfiles --create --prefix /var/log/journal

#At least set Storage=auto into config
emacs /etc/systemd/journald.conf

systemctl restart systemd-journald
```

##VIDEO
Add user to **video** group

```
sudo usermod -a -G video miner
```

To work with X server should  configure /etc/X11/Xwrapper.config with:

needs_root_rights=yes
allowed_users=anybody

Plus should add user to tty group
```
sudo apt-get install xserver-xorg-legacy
sudo usermod -a -G tty USER
```

### AMDGPU 17.40.+
Require ```sudo apt-get install linux-generic-hwe-16.04``` whould not work without this package
Edit /etc/default/grub as root and modify GRUB_CMDLINE_LINUX_DEFAULT in order to add "amdgpu.vm_fragment_size=9". 
The line may look something like this after the change: GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amdgpu.vm_fragment_size=9"
Update grub and reboot as root: ```update-grub; reboot```



## Net config
```
Edit your /etc/default/grub changing the line from

GRUB_CMDLINE_LINUX=""
to

GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0"
and, finally:

$ sudo update-grub
and reboot your system:

$ sudo reboot
```
Add to /etc/network/interfaces

```
auto eth0
iface eth0 inet dhcp
```

## SSHD
Use a Match block at the end of /etc/ssh/sshd_config:

PasswordAuthentication no

Match address 192.0.2.0/24
    PasswordAuthentication yes

