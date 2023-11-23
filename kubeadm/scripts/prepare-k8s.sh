#!/bin/bash

# Setup Versioning Variables (in-order)
CNI_PLUGINS_VERSION="v1.3.0"
ARCH="amd64"
CNI_DEST="/opt/cni/bin"
DOWNLOAD_DIR="/usr/local/bin"
CONTAINER_VERSION="v2.0.0-beta.0"
CRICTL_VERSION="v1.28.0" 
RUNC_VERSION="v1.1.10"
K8S_RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
KREL_VERSION="v0.16.2"

# Install CNI Plugins
sudo mkdir -p "$CNI_DEST"
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-${ARCH}-${CNI_PLUGINS_VERSION}.tgz" | sudo tar -C "$CNI_DEST" -xz
echo "#########--------CNI Plugins Installed.--------#########"

# Create the download directory for binaries
sudo mkdir -p "$DOWNLOAD_DIR"

# Download containerd and extract it
curl -L "https://github.com/containerd/containerd/releases/download/${CONTAINER_VERSION}/containerd-${CONTAINER_VERSION}-linux-${ARCH}.tar.gz" | sudo tar -C "$DOWNLOAD_DIR" -xzvf -

# Install crictl for kubeadm and CRI
curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz" | sudo tar -C $DOWNLOAD_DIR -xz
systemctl daemon-reload
systemctl enable --now containerd

# Install runc
curl -L "https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/run.${ARCH}.tar.gz"
sudo install -m 755 runc.${ARCH} /usr/local/sbin/runc

echo "#########--------Containerd and RUNC Installed.--------#########"

# Download and setup kubeadm and kubelet
cd $DOWNLOAD_DIR
sudo curl -L --remote-name-all https://dl.k8s.io/release/${K8S_RELEASE}/bin/linux/${ARCH}/{kubeadm,kubelet}
sudo chmod +x {kubeadm,kubelet}

curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${KREL_VERSION}/cmd/krel/templates/latest/kubelet/kubelet.service" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | sudo tee /etc/systemd/system/kubelet.service
sudo mkdir -p /etc/systemd/system/kubelet.service.d
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${KREL_VERSION}/cmd/krel/templates/latest/kubeadm/10-kubeadm.conf" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | sudo tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

echo "#########--------Kubeadm and Kubelet Configured--------#########"

# Download, install, and check kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client --output=yaml
kubectl cluster-info

# Enable and start kubelet
systemctl enable --now kubelet

echo "#########--------Kubernetes setup complete. Use kubectl to access...--------#########"