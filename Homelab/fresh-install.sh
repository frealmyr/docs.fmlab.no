#!/bin/bash

#
# This script was made for Ubuntu 18.04, some changes might be needed for other debian based distrobutions
#

echo "PROVISION: installing desired applications"
sudo apt update && sudo apt fullupgrade -y
sudo apt install -y ssh curl wget vim tlp-rdw intel-microcode smartmontools uidmap

echo "PROVISION: create ssh private key and create authorized key file"
mkdir ${HOME}/.ssh
ssh-keygen -b 2048 -t rsa -f ${HOME}/.ssh/id_rsa -q -N "" -C "FM-SRV"
touch ${HOME}/.ssh/authorized_keys

echo "PROVISION: Change logs location to wear-sacrifice SSD"
sudo /etc/init.d/rsyslog stop
sudo mv /var/log /media/SSD2/.logs
sudo ln -s /media/SSD2/.logs /var/log
sudo /etc/init.d/rsyslog start
echo "PROVISION: Change /tmp to RAMDISK and SWAP to wear-sacrifice SSD as fallback"
sudo echo "tmpfs /tmp tmpfs mode=1777,nosuid,nodev 0 0" >> /etc/fstab

echo "PROVISION: Rootless docker install"
## Run latest non-root docker install script
curl -fsSL https://get.docker.com/rootless | sh
## Update profile with DOCKER_HOST variable
echo "export DOCKER_HOST=unix:///run/user/1000/docker.sock" >> ~/.profile
## Allow docker to bind privileged ports <1000
sudo setcap cap_net_bind_service=ep $HOME/bin/rootlesskit
## Start docker once manually
systemctl --user start docker
## Start docker daemon on boot
systemctl --user enable docker

echo "PROVISION: download and install docker-compose"
curl -s https://api.github.com/repos/docker/compose/releases/latest \
| grep "browser_download_url.*docker-compose-`uname -s`-`uname -m`" \
| cut -d : -f 2,3 \
| tr -d \" \
| wget -qi -

SUMFILE=$(cat docker-compose-Linux-x86_64.sha256 | cut -d ' ' -f 1)
CHECKFILE=$(sha256sum docker-compose-Linux-x86_64 | cut -d ' ' -f 1)

if [ "$CHECKFILE" = "$SUMFILE" ]
then
  sudo mv docker-compose-Linux-x86_64 /usr/local/bin/docker-compose
  rm docker-compose-Linux-x86_64.sha256
  sudo chmod +x /usr/local/bin/docker-compose
else
  echo "Error: file hash checksum mismatch, re-download or check origin"
  echo ""
  echo "Downloaded file: ${SUMFILE}"
  echo "Checksum file: ${CHECKFILE}"
  echo ""
  echo "Error: docker-compose was not installed"
fi

echo "PROVISION: restarting in 10 seconds, close script to abort..."
sleep 10
sudo reboot
