#!/bin/bash
sudo apt-get install -y git ansible
ansible-galaxy collection install community.general
ansible-pull -U https://github.com/frealmyr/dotfiles.git main.yml
