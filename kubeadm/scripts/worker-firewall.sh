#!/bin/bash

LOCAL_NETWORK="192.168.x.x/24"

# Allow SSH on from the local network
sudo ufw allow from $LOCAL_NETWORK proto tcp to any port 22  # SSH

# Worker Node Ports
sudo ufw allow 10250/tcp  # Kubelet API
sudo ufw allow 30000:32767/tcp  # NodePort Services Range

# Enable the firewall
sudo ufw enable