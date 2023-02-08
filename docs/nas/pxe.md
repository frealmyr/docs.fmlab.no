# PXE Boot Raspberry Pi Cluster

The goal is the following:

  - Create a volume on Synology NAS for PXE booting Raspberry Pi.
  - Create a basic Raspbian image for our Raspberry Pi's.
  - Configure bootload on rPi to use PXE boot, with fallback to sdcard (if it is inserted).
  - Use ansible to configure multiple Raspberry Pi's
    - Packages, hostname, configuration, etc.
    - Log2ram (attempt to decrease disk i/o)
  - Use ansible to spin up a `kubeadm` Kubernetes cluster on Raspberry Pi's.

# What's needed?

Recommend the following prereqs:

  - Synology NAS
    - NVMe/SSD Storage volume, *not cache volume!*, see my other guides.
    - Static IP, or DHCP reservation, I don't discriminate.
    - Enable 802.3ad LACP for link aggregation (if you have a switch that supports it).
  - Raspberry Pi
    - DHCP resevations for each rPi node, as this will be used to for granting NFS permissions.
    - SDCard and card reader for dumping.

# Configure Synology DSM

Let's dive in, first we are going to configure our Synology NAS for TFTP

## 1. Configure DHCP Server


Option 43 vendor name is `Raspberry Pi Boot` by default
https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#PXE_OPTION43


## 1. Configure NFS

Enable the `NFS` service in `Control Panel`

![ ](\nas\images\pxe-1-nfs.png)

## 2. Create shares

I prefix my shares with `homelab-`, you can set this to whatever you want, as long as you change out the references in the next steps.

> Note that our shared folders will contain multiple sub-folders for each thin client.

### 2.1. Create two shares, one for boot files (TFTP) and one for root filesystems (PXE):

![ ](\nas\images\pxe-2-share-tftp.png)
![ ](\nas\images\pxe-2-share-pxe.png)

If you are using BTRFS (which you should), consider enabling data checksum for a small performance hit to avoid bitrot.

![ ](\nas\images\pxe-2-share-datachecksum.png)


### 2.2. On **both** shares you created, grant NFS permissions for each thin client IP address:

![ ](\nas\images\pxe-2-share-nfs.png)

## 3. Enable TFTP

Now that we have a shared folder for TFTP which contains boot files, we can enable and set the root folder for TFTP in DSM control panel:

![ ](\nas\images\pxe-3-enable-tftp.png)

## 4. Create re-usable base boot/OS folders

Now that we have configured DSM, we can create a base image for our Raspberry Pi's.

>When copying files from raspbian image to folders, make sure to retain the file permissions.

```bash
# Create temporary workdir
mkdir /volume2/@tmp/tmp-raspbian && cd /volume2/@tmp/tmp-raspbian/

# Download Raspbian archive
wget https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2022-09-26/2022-09-22-raspios-bullseye-arm64-lite.img.xz

# Uncompress rasbian archive, delete downloaded archive
7z x 2022-09-22-raspios-bullseye-arm64-lite.img.xz
rm 2022-09-22-raspios-bullseye-arm64-lite.img.xz

# Mount rasbian .img as a loop device
sudo losetup -f -P 2022-09-22-raspios-bullseye-arm64-lite.img
losetup -l

# Create base image folders
mkdir /volume2/netboot/tftp/base-image \
  /volume2/netboot/rootfs/base-image

# Mount boot partition on loop device, copy to TFTP base folder
sudo mkdir /mnt/raspbian
sudo mount /dev/loop0p1 /mnt/raspbian
sudo rsync -av /mnt/raspbian/ /volume2/netboot/tftp/base-image
sudo umount /mnt/raspbian

# Mount filesystem partition on loop device, copy to PXE base folder
sudo mount /dev/loop0p2 /mnt/raspbian
sudo rsync -av /mnt/raspbian/ /volume2/netboot/rootfs/base-image
sudo umount /mnt/raspbian

# Remove loop device, delete temporary files, navigate to root of volume
sudo losetup -d /dev/loop0
sudo rm -rf /mnt/raspbian
cd /volume2/
rm -rf /volume2/@tmp/tmp-raspbian/

# Configure base image
echo 'notice me sshenpai' | sudo tee /volume2/netboot/tftp/base-image/ssh.txt # Enable ssh
echo 'mgmt:$6$lHSvqL6/e/avgblH$Rfi4XHNMMmBiOeAvu.FRfEB0zZIPQ1YyLzPWq0lCu08FBQ75Gbcim9T714NGHQ.V/RcwfKoHEtu7j.TwRaour0' | sudo tee /volume2/netboot/tftp/base-image/userconf.txt # Temporary user/pass, to be replaced with ansible
```

We now have a fresh copy of Rasbian as a baseline image which we can duplicate for each connecting RPi.

## 5. Create TFTP/PXE folders for each Raspberry Pi

Booting a Raspberry Pi using TFTP requires the following:

  - A shared `bootcode.bin` file present on root of our `/volume2/netboot/tftp/` folder.
  - Individual folders under the TFTP nfs share, named after the RPi hardware serial number (by default), which contains the boot files.
  - Individual folders under the PXE nfs share, named after the RPi hardware serial number (by default), which contains the root filesystem
  - A DHCP server which hosts the RPi bootloader on PXE.
    - DHCP resevations for each RPi, as we must add it to the NFS allowlist.

During network boot, RPi4 looks for TFTP/PXE sub-folders on the NFS share with the serial number from the local RPi hardware. We are however going to configure the EEPROM to look for a folder named after the mac address, which is a lot more predictable.

> Source: https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#TFTP_PREFIX

### 5.1. Bootcode

Copy the `bootcode.bin` from our base image folder into the root of our TFTP folder:

```bash
sudo rsync -av /volume2/netboot/boot/base-image/bootcode.bin /volume2/netboot/boot

```

### 5.2. TFTP Boot folders

Copy the base image boot folder contents, to sub-folders in `/volume2/netboot/boot` with the mac addresses from the RPi devices:

```bash
sudo rsync -av /volume2/netboot/boot/base-image/ /volume2/netboot/boot/dc-a6-32-70-da-b0
sudo rsync -av /volume2/netboot/boot/base-image/ /volume2/netboot/boot/e4-5f-01-87-3e-e1
sudo rsync -av /volume2/netboot/boot/base-image/ /volume2/netboot/boot/e4-5f-01-87-56-36

```

Then configure the `/boot` entry in `/etc/fstab` for each folder, so that our RPi mounts their individual TFTP folders to `/boot` during boot.

```bash
sudo tee /volume2/netboot/boot/dc-a6-32-70-da-b0/cmdline.txt > /dev/null << EOF
console=serial0,115200  console=tty1  root=/dev/nfs nfsroot=10.10.0.11:/volume2/netboot/rootfs/dc-a6-32-70-da-b0,vers=4.1,proto=tcp,port=2049  rw  ip=dhcp elevator=deadline rootwait plymouth.ignore-serial-consoles
EOF
sudo tee /volume2/netboot/boot/e4-5f-01-87-3e-e1/cmdline.txt > /dev/null << EOF
console=serial0,115200  console=tty1  root=/dev/nfs nfsroot=10.10.0.11:/volume2/netboot/rootfs/e4-5f-01-87-3e-e1,vers=4.1,proto=tcp,port=2049  rw  ip=dhcp elevator=deadline rootwait plymouth.ignore-serial-consoles
EOF
sudo tee /volume2/netboot/boot/e4-5f-01-87-56-36/cmdline.txt > /dev/null << EOF
console=serial0,115200  console=tty1  root=/dev/nfs nfsroot=10.10.0.11:/volume2/netboot/rootfs/e4-5f-01-87-56-36,vers=4.1,proto=tcp,port=2049  rw  ip=dhcp elevator=deadline rootwait plymouth.ignore-serial-consoles
EOF

```

### 5.3. PXE filesystem folders

Copy the base image filesystem folder contents, to sub-folders in `/volume2/netboot/rootfs` with the mac addresses from the RPi devices:

```bash
sudo rsync -av /volume2/netboot/rootfs/base-image/ /volume2/netboot/rootfs/dc-a6-32-70-da-b0
sudo rsync -av /volume2/netboot/rootfs/base-image/ /volume2/netboot/rootfs/e4-5f-01-87-3e-e1
sudo rsync -av /volume2/netboot/rootfs/base-image/ /volume2/netboot/rootfs/e4-5f-01-87-56-36

```

Then configure the rootfs entry in `cmdline.txt`, for mounting the filesystem share for each RPi:

```bash
sudo tee /volume2/netboot/rootfs/dc-a6-32-70-da-b0/etc/fstab > /dev/null << EOF
proc  /proc proc  defaults  0 0
10.10.0.11:/volume2/netboot/boot/dc-a6-32-70-da-b0 /boot nfs defaults,vers=4.1,proto=tcp,port=2049 0 0
EOF
sudo tee /volume2/netboot/rootfs/e4-5f-01-87-3e-e1/etc/fstab > /dev/null << EOF
proc  /proc proc  defaults  0 0
10.10.0.11:/volume2/netboot/boot/e4-5f-01-87-3e-e1 /boot nfs defaults,vers=4.1,proto=tcp,port=2049 0 0
EOF
sudo tee /volume2/netboot/rootfs/e4-5f-01-87-56-36/etc/fstab > /dev/null << EOF
proc  /proc proc  defaults  0 0
10.10.0.11:/volume2/netboot/boot/e4-5f-01-87-56-36 /boot nfs defaults,vers=4.1,proto=tcp,port=2049 0 0
EOF

```

## 6. Configuring RPi EEPROM

The Synology NAS is now ready to serve TFTP/PXE to our RPis. The only thing missing, is to ssh into a RPi and configure EEPROM for network booting.

SSH into a Raspberry Pi, then run the following command to ensure that we have the latest EEPROM installed:

```bash
printf "\nlatest eeprom before update: $(rpi-eeprom-update -l)\n\n"
sudo apt update
sudo apt install -y rpi-eeprom
printf "\nlatest eeprom after update: $(rpi-eeprom-update -l)\n\n"

```

Copy the latest EEPROM binary to a temporary workdir:

```bash
mkdir /tmp/eeprom-config && cd /tmp/eeprom-config/
cp $(rpi-eeprom-update -l) /tmp/eeprom-config/

```

Create the a EEPROM config:

> Using Synology NAS Built-in DHCP Server, you will need to set `TFTP_IP=<yourserverip>` as it does not set `dhcp-option=tag:bond0,option:tftp-server-name,<yourserverip>` in `/etc/dhcpd/dhcpd.conf`. Which will make our RPi fallback to ip 0.0.0.0 for TFTP during network boot.
>
> You could add this to the `dhcpd.conf` file, but as I don't change network settings that often, I can live with static IP for TFTP.

```bash
tee bootconf.txt > /dev/null << EOF
[all]
BOOT_UART=0
WAKE_ON_GPIO=1
POWER_OFF_ON_HALT=0
BOOT_ORDER=0xf142
TFTP_IP=10.10.0.10
TFTP_PREFIX=2
NET_BOOT_MAX_RETRIES=3
EOF

```

  - TFTP_PREFIX=2: Use the MAC address for boot directory.
  - BOOT_ORDER=0xf142: `NETWORK -> USB-MSD -> SD CARD -> RESTART`.
  - TFTP_IP=10.10.0.10: Use static ip for TFTP server, as i have multiple gateways in my network.

Generate a new EEPROM binary with our configuration:

```bash
sudo rpi-eeprom-config --out pieeprom-custom.bin --config bootconf.txt $(basename -- $(rpi-eeprom-update -l))

```

Schedule writing of custom binary to EEPROM on reboot:

```bash
sudo rpi-eeprom-update -d -f ./pieeprom-custom.bin
```

Reboot to write EEPROM changes:

```bash
sudo reboot
```

>If all is working properly, the Raspberry Pi should boot using TFTP/PXE network boot.

I also found out that you can re-use the SD Card with the EEPROM update, power off the device and reboot it without the SD Card inserted.

## References

- https://kb.synology.com/en-us/DSM/help/DSM/AdminCenter/file_share_create?version=7
- https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#TFTP_IP
- https://docs.commscope.com/bundle/fastiron-08092-dhcpguide/page/GUID-5052B91F-07BF-4638-93FB-8C4B570037C4.html
- https://github.com/raspberrypi/documentation/blob/develop/documentation/asciidoc/computers/configuration/kernel-command-line-config.adoc
- https://dev.to/weeee/raspberry-pi-cluster-part-1-the-boot-2fe5
- https://superuser.com/questions/1480986/iptables-1-8-2-failed-to-initialize-nft-protocol-not-supported
- https://braindose.blog/2021/12/31/install-kubernetes-raspberry-pi/
- https://serverfault.com/questions/569528/iqn-naming-convention

- https://blogs.oracle.com/linux/post/xfs-data-block-sharing-reflink
- https://unix.stackexchange.com/questions/525613/xfs-vs-ext4-performance

- https://forum.qnap.com/viewtopic.php?t=58666