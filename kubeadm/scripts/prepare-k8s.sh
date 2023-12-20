#!/bin/bash

# Setup Versioning Variables

# Architecture
export ARCH="amd64"
export K8S_RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"

# System Versions
export CNI_PLUGINS_VERSION="v1.3.0"
export CONTAINER_VERSION="v1.7.8"
export CRICTL_VERSION="v1.28.0" 
export RUNC_VERSION="v1.1.10"
export KREL_VERSION="v0.16.2"

# Directories
export CNI_DEST="/opt/cni/bin"
export INSTALL_DIR="/usr/local/bin"
export KUBECTL_DIR="/usr/local/bin/kubectl"
export RUNC_DIR="/usr/local/sbin"
export SERVICE_DIR="/etc/systemd/system"

# Download, install, and check kubectl
echo -e "Removing any local old versions and downloading the latest version of kubectl...\n"

if [ -f ./kubectl ]; then 
    echo -e "Removing old kubectl downloads\n"
    rm -f kubectl 
fi

if [ -d $KUBECTL_DIR ]; then 
    echo -e "Cleaning up old kubectl install files\n"
    rm -rf $KUBECTL_DIR
fi

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"

# Validating kubectl binary
echo -e "Validating kubectl binary...\n\n"

if [ -f ./kubectl.sha256 ]; then 
    rm -f kubectl.sha256
fi

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl.sha256"

KUBECTL_CHECK="$(echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check)"

echo -e "$KUBECTL_CHECK\n"

if [ "$KUBECTL_CHECK" = "kubectl: OK" ]; then 
    echo -e "SHA256SUM CHECK SUCCESSFUL...\n"
else echo -e "SHA256SUM CHECK FAILED... please verify your download URLs for kubectl\n" 
    exit 1
fi

sudo install -o root -g root -m 0755 kubectl $KUBECTL_DIR

echo -e "##################----------------Kubectl verified and installed----------------##################\n\n"

echo -e "Installing containerd dependencies...\n"

# Create the download directory for binaries
sudo mkdir -p $INSTALL_DIR

# Download containerd and extract it
if [ -d ./containerd-${CONTAINER_VERSION}-linux-${ARCH} ]; then 
    echo -e "Target version of containerd already downloaded, skipping...\n" 
    sudo tar Cxzvf /usr/local containerd-${CONTAINER_VERSION}-linux-${ARCH}.tar.gz
    else wget https://github.com/containerd/containerd/releases/download/${CONTAINER_VERSION}/containerd-${CONTAINER_VERSION}-linux-${ARCH}.tar.gz | sudo tar Cxzvf /usr/local containerd-${CONTAINER_VERSION}-linux-${ARCH}.tar.gz
fi

# Setup containerd as a service
if [ -f ./containerd.service ]; then 
    echo -e "Removing old containerd.service unit...\n" 
    rm -f containerd.service
fi
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service 
sudo cp ./containerd.service $SERVICE_DIR/containerd.service

sudo systemctl daemon-reload
sudo systemctl enable --now containerd

echo -e "##################----------------Containerd installed and enabled----------------##################\n\n"


echo -e "##################----------------Installing RUNC and CNI Resources----------------##################\n\n"

# Install runc
if [ -d "${RUNC_DIR}/runc" ]; then 
    echo -e "RUNC already installed in ${RUNC_DIR}/runc\n" 
else 
    echo -e "Installing RUNC...\n"
    if curl -L "https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/runc.${ARCH}"; then
        echo -e "RUNC downloaded successfully.\n"
        if sudo install -m 755 "runc.$ARCH" "${RUNC_DIR}/runc"; then
            echo -e "RUNC installed successfully.\n"
        else
            echo -e "Failed to install RUNC. Please check permissions and try again.\n"
            exit 1
        fi
    else
        echo -e "Failed to download RUNC. Please check the URL and try again.\n"
        exit 1
    fi
fi

# Install CNI Plugins
if [ -d "$CNI_DEST" ]; then 
    echo -e "Cleaning up existing CNI resources...\n"
    if sudo rm -rf "$CNI_DEST"; then
        echo -e "CNI resources cleaned up successfully.\n"
    else
        echo -e "Failed to clean up CNI resources. Please check permissions and try again.\n"
        exit 1
    fi
fi

sudo mkdir -p $CNI_DEST

echo -e "Downloading and installing CNI Resources...\n"
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-${ARCH}-${CNI_PLUGINS_VERSION}.tgz" | sudo tar -C $CNI_DEST -xz

echo -e "##################----------------CNI Plugins and RUNC Installed.----------------##################\n\n"

# Download and setup kubeadm and kubelet
echo -e "Setting up kubeadm and kubelet...\n"

# Install crictl for kubeadm and CRI
if [ -d ${INSTALL_DIR}/crictl-$CRICTL_VERSION-linux-${ARCH} ]; then 
    echo -e "Proper crictl version already downloaded, skipping...\n" 
else 
    if [ -f ./crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz.sha256 ]; then 
        rm -f crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz.sha256
    fi

    curl -LO "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz.sha256"

    CRICTL_CHECK="$(echo "$(cat crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz.sha256)  crictl" | sha256sum --check)"

    echo -e "$CRICTL_CHECK\n"

    if [ "$CRICTL_CHECK" = "crictl: OK" ]; then 
        echo -e "SHA256SUM CHECK SUCCESSFUL...\n"
        wget curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz" | sudo tar -C $INSTALL_DIR -xz
    else echo -e "SHA256SUM CHECK FAILED... please verify your download URLs for kubectl\n" 
        exit 1
    fi
fi

cd $INSTALL_DIR
sudo curl -L --remote-name-all https://dl.k8s.io/release/${K8S_RELEASE}/bin/linux/${ARCH}/{kubeadm,kubelet}
sudo chmod +x {kubeadm,kubelet}

curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${KREL_VERSION}/cmd/krel/templates/latest/kubelet/kubelet.service" | sed "s:/usr/bin:${INSTALL_DIR}:g" | sudo tee ${SERVICE_DIR}/kubelet.service

if ! [ -f ${SERVICE_DIR}/kubelet.service.d ]; then 
    echo -e "Creating kubelet.service directory: ${SERVICE_DIR}/kubelet.service.d"
    sudo mkdir -p ${SERVICE_DIR}/kubelet.service.d 
fi

curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${KREL_VERSION}/cmd/krel/templates/latest/kubeadm/10-kubeadm.conf" | sed "s:/usr/bin:${INSTALL_DIR}:g" | sudo tee ${SERVICE_DIR}/kubelet.service.d/10-kubeadm.conf

echo -e "##################----------------Kubeadm and Kubelet Configured----------------##################\n\n"

echo -e "Testing cluster resources...\n"

sudo kubectl version --client --output=yaml

echo -e "###End version output###\n\n"
sudo kubectl cluster-info

echo -e "###End cluster info###\n\n"
# Enable and start kubelet
echo -e "Enabling kubectl with systemctl...\n"
sudo systemctl enable --now kubelet

echo "##################----------------Kubernetes setup complete. Use kubectl to access...----------------##################"