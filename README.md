# GL-MT300N-V2 OpenWrt Backup

This repository serves as a backup for OpenWrt ([23.05.4](https://openwrt.org/releases/23.05/notes-23.05.4)) configuration and setup for the **GL.iNet GL-MT300N-V2** mini router. For detailed hardware specifications, refer to the [OpenWrt device page](https://openwrt.org/toh/gl.inet/gl-mt300n_v2).

## Device Overview
The GL-MT300N-V2 is a compact router powered by a MediaTek MT7628NN SoC, featuring:
- **128 MB DRAM**
- **16 MB Flash**
- **1 USB 2.0 port** (supports extroot)
- **1 switch button**, **1 reset button**, and **3 LEDs**
- **Wi-Fi**: 2.4 GHz (b/g/n)
- **Power**: Micro USB

The latest official firmware is [**4.3.18**](https://dl.gl-inet.com/router/mt300n-v2/), based on [OpenWrt 22.03.4](https://openwrt.org/releases/22.03/notes-22.03.4). A backup of the stock firmware ([openwrt-mt300n-v2-4.3.18-0823-1724399860.stock.bin](./openwrt-mt300n-v2-4.3.18-0823-1724399860.stock.bin)) is included in this repository.

## 1. Upgrading to OpenWrt 23.05.4
To support extroot with external storage, include the following packages in the firmware:
- `block-mount`
- `kmod-fs-f2fs`
- `kmod-usb-storage`
- `mkf2fs`
- `f2fsck`

### Steps to Upgrade
1. Visit the [OpenWrt Firmware Selector](https://firmware-selector.openwrt.org/).
2. Select **GL.iNet GL-MT300N-V2** and add the packages listed above under *Installed Packages*.
3. Request a custom build.
4. Download the prebuilt firmware:
   - **Filename**: `openwrt-23.05.4-4c0b783b0436-ramips-mt76x8-glinet_gl-mt300n-v2-squashfs-sysupgrade.bin`
   - **SHA256**: `bb736757a6369a8457dc19d727fae4a85199cb02813b356e33b532e5e24767a9`
5. Flash the firmware via the GL.iNet web interface:
   - Navigate to **Upgrade > Local Upgrade** or access LuCI:
     - **Option 1**: Left sidebar > *More Settings > Advanced*
     - **Option 2**: Click the *Advanced>>* link in the top-right corner.
6. Upload the firmware and reboot the device.

## 2. Setting Up Extroot with USB Storage
To expand storage using a USB drive, follow these steps:

1. Connect a USB disk (recommended: >256 MB) to the GL-MT300N-V2.
2. Power on the device and connect it to your PC via LAN cable.
3. Set your PC's IP to `192.168.1.x` and SSH into the router:
   ```shell
   ssh root@192.168.1.1
   ```
4. Check block device information:
   ```shell
   block info
   ```
   Example output:
   ```
   /dev/mtdblock5: UUID="9fd43c61-c3f2c38f-13440ce7-53f0d42d" VERSION="4.0" MOUNT="/rom" TYPE="squashfs"
   /dev/mtdblock6: MOUNT="/overlay" TYPE="jffs2"
   /dev/sda1: UUID="fdacc9f1-0e0e-45ab-acee-9cb9cc8d7d49" VERSION="1.4" TYPE="ext4"
   ```
5. Mount the current filesystem to `/rwm`:
   ```shell
   DEVICE="$(sed -n -e "/\s\/overlay\s.*$/s///p" /etc/mtab)"
   uci -q delete fstab.rwm
   uci set fstab.rwm="mount"
   uci set fstab.rwm.device="${DEVICE}"
   uci set fstab.rwm.target="/rwm"
   uci commit fstab
   ```
6. Format the USB disk as `f2fs`:
   ```shell
   mkfs.f2fs /dev/sda1
   ```
7. Configure the overlay filesystem on the USB disk:
   ```shell
   DEVICE="/dev/sda1"
   eval $(block info ${DEVICE} | grep -o -e "UUID=\S*")
   uci -q delete fstab.overlay
   uci set fstab.overlay="mount"
   uci set fstab.overlay.uuid="${UUID}"
   uci set fstab.overlay.target="/overlay"
   uci commit fstab
   ```
8. Copy the filesystem to the USB disk:
   ```shell
   DEVICE="/dev/sda1"
   mkdir -p /tmp/cproot
   mount --bind /overlay /tmp/cproot
   mount ${DEVICE} /mnt
   tar -C /tmp/cproot -cvf - . | tar -C /mnt -xf -
   umount /tmp/cproot /mnt
   ```
9. Reboot the device:
   ```shell
   reboot
   ```
10. Verify the disk setup:
    ```shell
    df -h
    ```

**Reference**: [GL.iNet Forum](https://forum.gl-inet.cn/forum.php?extra=&mod=viewthread&tid=14)

## 3. Connecting to the Internet
To connect the GL-MT300N-V2 to the internet, restore network configurations if available.

1. Backup existing configuration files:
   ```shell
   cp /etc/config/firewall /etc/config/firewall.bk
   cp /etc/config/network /etc/config/network.bk
   cp /etc/config/wireless /etc/config/wireless.bk
   cp /etc/config/system /etc/config/system.bk
   ```
2. Restore configuration files from your PC:
   ```shell
   scp ./rootfs/etc/config/network root@192.168.1.1:/etc/config/
   scp ./rootfs/etc/config/wireless root@192.168.1.1:/etc/config/
   scp ./rootfs/etc/config/firewall root@192.168.1.1:/etc/config/
   scp ./rootfs/etc/config/system root@192.168.1.1:/etc/config/
   scp ./rootfs/etc/freememory.sh root@192.168.1.1:/etc/
   scp ./profile root@192.168.1.1:~/.profile
   reboot
   ```
3. Power down, connect the router to the internet via LAN, and power on.
4. Verify connectivity and SSH access. The default Wi-Fi settings are:
   - **SSID**: `GL-MT300N-V2-xxx`
   - **Password**: `goodlife`
   - **Hostname**: `gl-MT300N-v2`
5. Disconnect the LAN cable and connect via Wi-Fi.

## 4. Installing Backup Packages
Install additional packages to enhance functionality.

1. SSH into the router (new IP: `192.168.8.1`):
   ```shell
   ssh root@192.168.8.1
   ```
2. Install essential packages:
   ```shell
   opkg update
   opkg install fuse-utils glib2 dropbearconvert usbutils bzip2 rename rsync tree unrar whereis nano lsof htop perl bc
   chmod +x /etc/freememory.sh
   ```
3. Schedule the `freememory.sh` script to run every 2 hours:
   ```shell
   crontab -e
   ```
   Add:
   ```
   0 */2 * * * /etc/freememory.sh
   ```
4. Restore the package list from stock firmware 4.3.18:
   ```shell
   scp ./rootfs/list-installed.txt root@192.168.8.1:/tmp
   opkg update
   cat /tmp/list-installed.txt | xargs opkg install
   ```
   **Note**: The `list-installed.txt` file is based on firmware 4.3.18. Verify compatibility before installation.
5. Use `bk_pkg_list.sh` to back up the installed package list.

## 5. Installing Avahi Daemon
Enable mDNS for local network discovery.

```shell
opkg update
opkg install avahi-dbus-daemon avahi-utils
```

**Local Domain**: `gl-mt300n-v2.local`

## 6. Installing Aria2
Set up a download manager with a web interface.

```shell
opkg update
opkg install aria2 luci-app-aria2 ariang-nginx
mkdir -p /root/share/downloads
chmod 777 -R /root/share/downloads
```

Restore configuration:
```shell
scp ./rootfs/etc/config/aria2 root@192.168.8.1:/etc/config/
```

- **Download Folder**: `/root/share/downloads`
- **Web Interface**: `http://192.168.8.1/ariang/index.html`

## 7. Installing Simple Adblock
Block ads on the network.

```shell
opkg update
opkg install simple-adblock luci-app-simple-adblock
uci set simple-adblock.config.enabled='1'
uci commit simple-adblock
```

Restore configuration:
```shell
scp ./rootfs/etc/config/simple-adblock root@192.168.8.1:/etc/config/
```

## 8. Installing ttyd
Enable a web-based terminal.

```shell
opkg update
opkg install ttyd luci-app-ttyd
```

Restore configuration:
```shell
scp ./rootfs/etc/config/ttyd root@192.168.8.1:/etc/config/
```

- **Port**: `800` (accessible only on `192.168.8.*`)

## 9. Installing MiniDLNA
Set up a media server.

```shell
opkg update
opkg install minidlna luci-app-minidlna
```

Restore configuration:
```shell
scp ./rootfs/etc/config/minidlna root@192.168.8.1:/etc/config/
```

- **Media Scan Path**: `/root/share`

## 10. Installing Convenient LuCI Apps
Enhance the LuCI interface.

```shell
opkg update
opkg install luci-app-acl luci-app-commands
```

## 11. Installing SSH Tunnel Client
Set up an SSH tunnel for secure connections.

```shell
opkg update
opkg install sshtunnel
cd ~
mkdir .ssh
chmod 700 .ssh/
dropbearkey -t rsa -f /root/.ssh/id_dropbear
```

Copy the public key to the SSH server:
```shell
vi ~/.ssh/id_rsa.pub
scp -p [port] ~/.ssh/id_rsa.pub [account]@[my.ssh.server]:~/.ssh/authorized_keys
```

Convert the Dropbear key:
```shell
dropbearconvert dropbear openssh ~/.ssh/id_dropbear ~/.ssh/id_rsa
```

Restore configuration:
```shell
scp ./rootfs/etc/config/sshtunnel root@192.168.8.1:/etc/config/
```

- **Proxy Port**: `1234`
- **SOCKS v5 Proxy**: `socket://192.168.8.1:1234`
- **Reference**: [SOCKS Proxy Setup](https://blog.thestateofme.com/2022/10/26/socks-proxy-ssh-tunnels-on-openwrt/)

## 12. Installing Polipo
Set up an HTTP proxy based on the SOCKS proxy.

```shell
opkg update
opkg install polipo luci-app-polipo
```

Restore configuration:
```shell
scp ./rootfs/etc/config/polipo root@192.168.8.1:/etc/config/
```

- **HTTP Proxy Port**: `4321`
- **HTTP Proxy**: `http://192.168.8.1:4321`
- **Reference**: [SOCKS Proxy Setup](https://blog.thestateofme.com/2022/10/26/socks-proxy-ssh-tunnels-on-openwrt/)

## 13. Installing Samba
Enable file sharing.

```shell
opkg update
opkg install samba4-server luci-app-samba4
```

Restore configuration:
```shell
scp ./rootfs/etc/config/samba4 root@192.168.8.1:/etc/config/
```

## 14. Installing Alist
Set up a file-sharing service.

```shell
sh -c "$(curl -ksS https://raw.githubusercontent.com/sbwml/luci-app-alist/master/install.sh)"
```

This installs:
- `alist*.ipk`
- `luci-app-alist*.ipk`
- `luci-i18n*.ipk`

Restore configuration:
```shell
scp ./rootfs/etc/config/alist root@192.168.8.1:/etc/config
```

- **Access Port**: `8080` (LAN access only)
- **Web Interface**: `http://192.168.8.1:8080`
- **Setup**: Configure the storage mount path in the *Storage* tab.
- **Reference**: [Alist GitHub](https://github.com/sbwml/luci-app-alist/)
