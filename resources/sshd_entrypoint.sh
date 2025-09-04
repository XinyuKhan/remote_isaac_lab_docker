#!/bin/bash

mkdir -p /home/$USER/.ssh
if [ ! -f /home/$USER/.ssh/id_rsa ]; then
  echo "Generating SSH keys for user $USER..."
  ssh-keygen -t rsa -b 4096 -f /home/$USER/.ssh/id_rsa -N ""
  cat /home/$USER/.ssh/id_rsa.pub >> /home/$USER/.ssh/authorized_keys
  chmod 600 /home/$USER/.ssh/authorized_keys
  sudo mkdir -p /etc/export_keys
  sudo cp -f /home/$USER/.ssh/id_rsa.pub /etc/export_keys/id_rsa.pub 
  sudo cp -f /home/$USER/.ssh/id_rsa /etc/export_keys/id_rsa
fi


echo "Starting SSH daemon..."
sudo /usr/sbin/sshd -D

