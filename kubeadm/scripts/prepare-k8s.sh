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
RUNC_DIR="/usr/local/sbin"
SERVICE_DIR="/etc/systemd/system"

# Download, install, and check kubectl
echo -e "Removing any local old versions and downloading the latest version of kubectl...\n"

if [ -f ./kubectl]; then 
    echo -e "Removing old kubectl downloads"
    rm -f kubectl 
fi

if [ -d $KUBECTL_DIR]; then 
    echo -e "Cleaning up old kubectl install files"
    rm -rf $KUBECTL_DIR
fi

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"

# Validating kubectl binary
echo -e "Validating kubectl binary...\n\n"

if [ -f ./kubectl.sha256]; then 
    rm -f kubectl.sha256
fi

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl.sha256"

echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

if [$(echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check) -e "kubectl: OK"]; then 
    echo -e "sha256sum check SUCCESSFUL..." break 
else echo -e "sha256sum check FAILED... please verify your download URLs for kubectl\n" 
    exit 1
fi

sudo install -o root -g root -m 0755 kubectl $KUBECTL_DIR

echo -e "Installing containerd dependencies...\n"

# Create the download directory for binaries
sudo mkdir -p "$INSTALL_DIR"

# Download containerd and extract it
if [ -d ./containerd-${CONTAINER_VERSION}-linux-${ARCH}]; then 
    echo -e "Target version of containerd already downloaded, skipping...\n" 
    else wget https://github.com/containerd/containerd/releases/download/v${CONTAINER_VERSION}/containerd-${CONTAINER_VERSION}-linux-${ARCH}.tar.gz | sudo tar Cxzvf /usr/local containerd-${CONTAINER_VERSION}-linux-${ARCH}.tar.gz
fi

# Setup containerd as a service
if [ -f ./containerd.service]; then 
    echo -e "Removing old containerd.service unit...\n" 
    rm -f containerd.service
fi
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service 
sudo cp ./containerd.service ${SERVICE_DIR}/containerd.service

sudo systemctl daemon-reload
sudo systemctl enable --now containerd

# Install runc
if [ -d ${RUNC_DIR}/runc]; then 
    echo "RUNC already installed in ${RUNC_DIR}/runc\n" 
else 
    curl -L "https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/run.${ARCH}.tar.gz"
    sudo install -m 755 runc.${ARCH} ${RUNC_DIR}/runc
fi

# Install CNI Plugins
if [ -d $CNI_DEST]; then 
    echo "Cleaning up existing CNI resources...\n"
    sudo rm -rf $CNI_DEST
else 
    sudo mkdir -p "$CNI_DEST"
fi

echo -e "Downloading and installing CNI Resources...\n"
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-${ARCH}-${CNI_PLUGINS_VERSION}.tgz" | sudo tar -C $CNI_DEST -xz

echo -e "#########--------Containerd, CNI Plugins, and RUNC Installed.--------#########\n\n"

# Download and setup kubeadm and kubelet
echo -e "Setting up kubeadm and kubelet...\n"

# Install crictl for kubeadm and CRI
if [ -f ${INSTALL_DIR}/crictl-${CRICTL_VERSION}-linux-${ARCH}]; then 
    echo -e "Proper crictl version already downloaded, skipping...\n" 
    else wget curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz" | sudo tar -C $INSTALL_DIR -xz
fi

cd $INSTALL_DIR
sudo curl -L --remote-name-all https://dl.k8s.io/release/${K8S_RELEASE}/bin/linux/${ARCH}/{kubeadm,kubelet}
sudo chmod +x {kubeadm,kubelet}

curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${KREL_VERSION}/cmd/krel/templates/latest/kubelet/kubelet.service" | sed "s:/usr/bin:${INSTALL_DIR}:g" | sudo tee ${SERVICE_DIR}/kubelet.service

if ! [-f ${SERVICE_DIR}/kubelet.service.d]; then 
    echo -e "Creating kubelet.service directory: ${SERVICE_DIR}/kubelet.service.d"
    sudo mkdir -p ${SERVICE_DIR}/kubelet.service.d 
fi

curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${KREL_VERSION}/cmd/krel/templates/latest/kubeadm/10-kubeadm.conf" | sed "s:/usr/bin:${INSTALL_DIR}:g" | sudo tee ${SERVICE_DIR}/kubelet.service.d/10-kubeadm.conf

echo -e "#########--------Kubeadm and Kubelet Configured--------#########\n\n"

echo -e "Testing cluster resources...\n"

sudo kubectl version --client --output=yaml

echo -e "###End version output###\n\n"
sudo kubectl cluster-info

echo -e "###End cluster info###\n\n"
# Enable and start kubelet
echo -e "Enabling kubectl with systemctl...\n"
sudo systemctl enable --now kubelet

echo "#########--------Kubernetes setup complete. Use kubectl to access...--------#########"