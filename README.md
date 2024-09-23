# GL-MT300N-V2-openwrt-bk

### This is the backup repo for openwrt([23.05.4](https://openwrt.org/releases/23.05/notes-23.05.4)) of GL.iNet GL-MT300N V2
https://openwrt.org/toh/gl.inet/gl-mt300n_v2

GL-MT300N-V2 is a mobile router based on MediaTek MT7628NN with 128MB dram, 16MB flash memory.

GL-MT300N-V2 has 1 USB 2.0 port which can used for exroot, 1 switch button, 1 reset button and 3 LEDS.

GL-MT300N-V2 supports WLAN 2.4GHz(b/g/n) and is powered by micro USB

#### 1. Replace [OEM stock firmware](https://dl.gl-inet.com/router/mt300n-v2/) with [openwrt 23.05.4](https://openwrt.org/releases/23.05/notes-23.05.4)

Due to extroot with external storage, we need to add following pkg into the openwrt firmware.
1. block-mount
2. kmod-fs-f2fs
3. kmod-usb-storage
4. mkf2fs
5. f2fsck

Access [OpenWrt Firmware Selector](https://firmware-selector.openwrt.org/) , input **GL.iNet GL-MT300N V2** , add **block-mount kmod-fs-f2fs kmod-usb-storage mkf2fs f2fsck** into _Installed Packages_, Then _request build_.

[**openwrt-23.05.4-4c0b783b0436-ramips-mt76x8-glinet_gl-mt300n-v2-squashfs-sysupgrade.bin**](openwrt-23.05.4-4c0b783b0436-ramips-mt76x8-glinet_gl-mt300n-v2-squashfs-sysupgrade.bin) is the prebuilt firmware with the packages above insalled. 
* filename : openwrt-23.05.4-4c0b783b0436-ramips-mt76x8-glinet_gl-mt300n-v2-squashfs-sysupgrade.bin
* sha256sum: bb736757a6369a8457dc19d727fae4a85199cb02813b356e33b532e5e24767a9

You can just follow [Normal upgrade](https://openwrt.org/toh/gl.inet/installation#normal_upgrade) to sysupgrade the device firmware.

Access the GL.Inet web interface to re-flash your device using OpenWrt (Upgrade > Local Upgrade).

You can also access LuCi (the normal OpenWrt web interface) and from there you can upload and install a new OpenWrt firmware as normal. Depending on the web interface version, you can access LuCi:

1. In the left sidebar: More Settings > Advanced
2. By clicking on the small grey “Advanced>>” link you find in the top right of the device's web interface.

Once upgraded, reboot GL-MT300N-V2.

#### 2. Extroot with external USB storage
1. Prepare a USB disk(better larger than 256MB) and connect with GL-MT300N-V2
2. power on GL-MT300N-V2 and connect it to your PC with LAN Cable.
3. Set PC ip as 192.168.1.x and connect GL-MT300N-V2 with ssh

on PC :
```shell
ssh root@192.168.1.1
```

4. Check block information. (foud out USB device -> /dev/sdax)

on GL-MT300N-V2(192.168.1.1) :
```shell
block info
```
>     /dev/mtdblock5: UUID="9fd43c61-c3f2c38f-13440ce7-53f0d42d" VERSION="4.0" MOUNT="/rom" TYPE="squashfs"
>     /dev/mtdblock6: MOUNT="/overlay" TYPE="jffs2"
>     /dev/sda1: UUID="fdacc9f1-0e0e-45ab-acee-9cb9cc8d7d49" VERSION="1.4" TYPE="ext4"

5. Edit fstab to mount current filsystem on /rwm

on GL-MT300N-V2(192.168.1.1) :
```shell
DEVICE="$(sed -n -e "/\s\/overlay\s.*$/s///p" /etc/mtab)"
uci -q delete fstab.rwm
uci set fstab.rwm="mount"
uci set fstab.rwm.device="${DEVICE}"
uci set fstab.rwm.target="/rwm"
uci commit fstab
```

6. Format USB disk as f2fs.

on GL-MT300N-V2(192.168.1.1) :
```shell
mkfs.f2fs /dev/sda1
```

7. Edit fstab to overlay filesystem on external storage

on GL-MT300N-V2(192.168.1.1) :
```shell
DEVICE="/dev/sda1"
eval $(block info ${DEVICE} | grep -o -e "UUID=\S*")
uci -q delete fstab.overlay
uci set fstab.overlay="mount"
uci set fstab.overlay.uuid="${UUID}"
uci set fstab.overlay.target="/overlay"
uci commit fstab
```

8. Copy filesystem to USB disk(/dev/sda1)

on GL-MT300N-V2(192.168.1.1) :
```shell
DEVICE="/dev/sda1"
mkdir -p /tmp/cproot
mount --bind /overlay /tmp/cproot
mount ${DEVICE} /mnt
tar -C /tmp/cproot -cvf - . | tar -C /mnt -xf -        
umount /tmp/cproot /mnt
```

9. Reboot GL-MT300N-V2

on GL-MT300N-V2(192.168.1.1) :
```shell
reboot
```

10. Check disk information
on GL-MT300N-V2(192.168.1.1) :
```shell
df -h
```

___reference___ : https://forum.gl-inet.cn/forum.php?extra=&mod=viewthread&tid=14

#### 3. Connect GL-MT300N-V2 to internet

Try to connect GL-MT300N-V2 to internet. If you have config backup for network, just restore them with scp.

on PC :
```shell
ssh root@192.168.1.1
```

Before restore config files, backup original config files.

on GL-MT300N-V2(192.168.1.1) :
```shell
cp /etc/config/firewall /etc/config/firewall.bk
cp /etc/config/network /etc/config/network.bk
cp /etc/config/wireless /etc/config/wireless.bk
cp /etc/config/system /etc/config/system.bk
```

scp config files into raspberry pi to restore config files.

on PC :
```shell
scp ./rootfs/etc/config/network root@192.168.1.1:/etc/config/
scp ./rootfs/etc/config/wireless root@192.168.1.1:/etc/config/
scp ./rootfs/etc/config/firewall root@192.168.1.1:/etc/config/
scp ./rootfs/etc/config/system root@192.168.1.1:/etc/config/
scp ./rootfs/etc/freememory.sh root@192.168.1.1:/etc/
scp ./profile root@192.168.1.1:~/.profile
reboot
```

Power down GL-MT300N-V2 and connect GL-MT300N-V2 to internet with LAN cable then power on.
Please make sure GL-MT300N-V2 connect to internet and you can ssh into the device.

If success, you will see the wifi signal as below.

The SSID is **GL-MT300M-V2-xxx** , connection password is **goodlife** , local hostname is **gl-mt300m-v2**

unplug LAN cable and connect to GL-MT300M-V2 via wifi.

#### 4. Install backup pkg (in GL-MT300M-V2)

login to GL-MT300M-V2 on PC :

on PC :
```shell
ssh root@192.168.8.1
```

on GL-MT300M-V2(192.168.8.1) :
```shell
opkg update
opkg install fuse-utils glib2 dropbearconvert usbutils bzip2 rename rsync tree unrar whereis nano lsof htop perl bc
chmod +x /etc/freememory.sh
crontab -e
```
> 0 */2 * * * /etc/freememory.sh

Or just restore with list-installed.txt. (just check the txt file for what will be installed)

on PC :
```shell
scp ./rootfs/list-installed.txt root@192.168.8.1:/tmp
```

on GL-MT300M-V2(192.168.8.1) :
```shell
opkg update
cat /tmp/list-installed.txt | xargs opkg install
```

**bk_pkg_list.sh** is the script to back up your opkg installed list.


#### 5. <TBD>

avahi-dbus-daemon avahi-utils

ttyd luci-app-ttyd

samba4-server luci-app-samba4

minidlna luci-app-minidlna 

sshtunnel 

luci-app-acl luci-app-commands

polipo luci-app-polipo

alist