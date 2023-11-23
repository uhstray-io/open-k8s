#!/bin/bash

# Replace with your local network IP range
LOCAL_NETWORK="192.168.1.0/24"

# Allow SSH only from the local network
sudo ufw allow from $LOCAL_NETWORK proto tcp to any port 22 

# Control Plane Ports
sudo ufw allow 6443/tcp  # Kubernetes API server
sudo ufw allow 2379:2380/tcp  # etcd server client API
sudo ufw allow 10259/tcp  # kube-scheduler
sudo ufw allow 10257/tcp  # kube-controller-manager

# Enable the firewall
sudo ufw enable