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

sudo tee /etc/profile.d/docker_proxy_env.sh >/dev/null <<EOF
export PROXY_ADDR="${PROXY_ADDR:-172.17.0.1}"
export PROXY_PORT_HTTP="${PROXY_PORT_HTTP:-10808}"
export PROXY_PORT_HTTPS="${PROXY_PORT_HTTPS:-10808}"
export SHELL_AUTO_PROXY="${SHELL_AUTO_PROXY:-false}"
EOF

sudo chmod 644 /etc/profile.d/docker_proxy_env.sh

echo "Starting SSH daemon..."
sudo -E /usr/sbin/sshd -D

