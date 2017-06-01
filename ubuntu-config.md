# Packages

```
apt-get install emacs-nox mc tmux vnstat libcurl3
apt-get purge nano snapd snap-confine mdadm cryptsetup
```

Configure sensors
```
apt-get install  lm-sensors
# Now you should detect sensors
sudo sensors-detect

```
And just follow the prompts. Add the recommended lines to /etc/modules.
After uninstall cryptsetup dudes suggest to reconfigure/install grub


```
sudo update-grub
sudo grub-install /dev/<your_device_id>
```

# Build tools

# Configuration 

Add user to **video** group

```
sudo usermod -a -G video miner
```

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

