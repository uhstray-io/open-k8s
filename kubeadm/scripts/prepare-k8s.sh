#!/bin/bash

# Setup Versioning Variables

# Architecture
ARCH="amd64"
K8S_RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"

# System Versions
CNI_PLUGINS_VERSION="v1.3.0"
CONTAINER_VERSION="1.7.8"
CRICTL_VERSION="v1.28.0" 
RUNC_VERSION="v1.1.10"
KREL_VERSION="v0.16.2"

# Directories
CNI_DEST="/opt/cni/bin"
INSTALL_DIR="/usr/local/bin"
KUBECTL_DIR="/usr/local/bin/kubectl"
SERVICE_DIR="/etc/systemd/system"

echo -e "Installing container dependencies...\n"

# Install CNI Plugins
sudo mkdir -p "$CNI_DEST"
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-${ARCH}-${CNI_PLUGINS_VERSION}.tgz" | sudo tar -C "$CNI_DEST" -xz
echo -e "#########--------CNI Plugins Installed.--------#########\n\n"

# Create the download directory for binaries
sudo mkdir -p "$INSTALL_DIR"

# Download containerd and extract it
wget "https://github.com/containerd/containerd/releases/download/${CONTAINER_VERSION}/containerd-${CONTAINER_VERSION}-linux-${ARCH}.tar.gz" | sudo tar -C "$INSTALL_DIR" -xvf -


wget https://github.com/containerd/containerd/releases/download/v${CONTAINER_VERSION}/containerd-${CONTAINER_VERSION}-linux-${ARCH}.tar.gz | sudo tar xvf containerd-${CONTAINER_VERSION}-linux-${ARCH}.tar.gz

# Setup containerd as a service
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service 
sudo cp ./containerd.service ${SERVICE_DIR}/containerd.service

# Install crictl for kubeadm and CRI
curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz" | sudo tar -C $INSTALL_DIR -xz
sudo systemctl daemon-reload
sudo systemctl enable --now containerd

# Install runc
curl -L "https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/run.${ARCH}.tar.gz"
sudo install -m 755 runc.${ARCH} ${INSTALL_DIR}/runc

echo -e "#########--------Containerd and RUNC Installed.--------#########\n\n"

# Download and setup kubeadm and kubelet
echo -e "Setting up kubeadm and kubelet...\n"

cd $INSTALL_DIR
sudo curl -L --remote-name-all https://dl.k8s.io/release/${K8S_RELEASE}/bin/linux/${ARCH}/{kubeadm,kubelet}
sudo chmod +x {kubeadm,kubelet}

curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${KREL_VERSION}/cmd/krel/templates/latest/kubelet/kubelet.service" | sed "s:/usr/bin:${INSTALL_DIR}:g" | sudo tee ${SERVICE_DIR}/kubelet.service
sudo mkdir -p ${SERVICE_DIR}/kubelet.service.d
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${KREL_VERSION}/cmd/krel/templates/latest/kubeadm/10-kubeadm.conf" | sed "s:/usr/bin:${INSTALL_DIR}:g" | sudo tee ${SERVICE_DIR}/kubelet.service.d/10-kubeadm.conf

echo -e "#########--------Kubeadm and Kubelet Configured--------#########\n\n"

# Download, install, and check kubectl
echo -e "Installing kubectl...\n"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"

echo -e "Validating kubectl binary...\n\n"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl.sha256"

echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

sudo install -o root -g root -m 0755 kubectl $KUBECTL_DIR

sudo kubectl version --client --output=yaml

echo -e "###End version output###\n\n"
sudo kubectl cluster-info

echo -e "###End cluster info###\n\n"
# Enable and start kubelet
echo -e "Enabling kubectl with systemctl...\n"
sudo systemctl enable --now kubelet

echo "#########--------Kubernetes setup complete. Use kubectl to access...--------#########"