set -e
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

KUBECTL_VERSION_URL="https://dl.k8s.io/release/stable.txt"
KUBECTL_BINARY_URL="https://dl.k8s.io/release/$(curl -L -s $KUBECTL_VERSION_URL)/bin/linux/${ARCH}/kubectl"
KUBECTL_SHA_URL="${KUBECTL_BINARY_URL}.sha256"
CONTAINERD_SERVICE_URL="https://raw.githubusercontent.com/containerd/containerd/main/containerd.service"

echo -e "Removing any local old versions and downloading the latest version of kubectl...\n"


# If the kubectl directory exists, clean it up
if [ -d $KUBECTL_DIR ]; then 
    echo -e "Cleaning up old kubectl install files\n"
    rm -rf $KUBECTL_DIR
fi

# If a local kubectl binary exists, remove it
if [ -f ./kubectl ]; then 
    echo -e "Removing old kubectl downloads\n"
    rm -f kubectl 
fi

# Print a message about what the script is doing
echo "Downloading the latest version of kubectl..."
curl -LO $KUBECTL_BINARY_URL

# Validating kubectl binary
echo -e "Validating kubectl binary...\n\n"
if [ -f ./kubectl.sha256 ]; then 
    rm -f kubectl.sha256
fi

curl -LO $KUBECTL_SHA_URL

KUBECTL_CHECK="$(echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check)"

echo -e "$KUBECTL_CHECK\n"

if [ "$KUBECTL_CHECK" = "kubectl: OK" ]; then 
    echo -e "SHA256SUM CHECK SUCCESSFUL...\n"
else 
    echo -e "SHA256SUM CHECK FAILED... please verify your download URLs for kubectl\n" 
    exit 1
fi

sudo install -o root -g root -m 0755 kubectl $KUBECTL_DIR

echo -e "====================== Kubectl verified and installed ======================\n\n"




# Print a message about what the script is doing
echo -e "Installing containerd dependencies...\n"

# Create the download directory for binaries
echo -e "Creating directory for binaries...\n"
sudo mkdir -p $INSTALL_DIR

# Download containerd and extract it
echo -e "Checking for existing containerd download...\n"
if [ -d ./containerd-${CONTAINER_VERSION}-linux-${ARCH} ]; then 
    echo -e "Target version of containerd already downloaded, skipping download and extracting...\n" 
    sudo tar Cxzvf /usr/local containerd-${CONTAINER_VERSION}-linux-${ARCH}.tar.gz
else 
    echo -e "Downloading containerd...\n"
    wget -O containerd-${CONTAINER_VERSION}-linux-${ARCH}.tar.gz https://github.com/containerd/containerd/releases/download/${CONTAINER_VERSION}/containerd-${CONTAINER_VERSION}-linux-${ARCH}.tar.gz | sudo tar Cxzvf /usr/local containerd-${CONTAINER_VERSION}-linux-${ARCH}.tar.gz
fi

# Check for existing containerd service unit and remove if exists
echo -e "Checking for existing containerd service unit...\n"
if [ -f ./containerd.service ]; then 
    echo "Found existing containerd service unit. Removing..."
    rm -f containerd.service
fi

# Download containerd service unit
echo "Downloading containerd service unit..."
wget -O containerd.service $CONTAINERD_SERVICE_URL

# Copy the service unit to the service directory
echo "Copying containerd service unit to service directory..."
sudo cp ./containerd.service $SERVICE_DIR/containerd.service

# Reload the systemd daemon and enable containerd service
echo "Reloading systemd daemon and enabling containerd service..."
sudo systemctl daemon-reload
sudo systemctl enable --now containerd

echo -e "====================== Containerd installed and enabled. ======================\n"

echo -e "====================== Preparing to install RUNC and CNI Resources.... ======================\n"





# Install runc
if [ -d "${RUNC_DIR}/runc" ]; then 
    echo -e "RUNC already installed in ${RUNC_DIR}/runc\n" 
else 
    echo -e "Installing RUNC...\n"
    if wget "https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/runc.${ARCH}"; then
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

echo -e "====================== CNI Plugins and RUNC Installed. ======================\n\n"




# Download and setup kubeadm and kubelet
echo -e "Setting up kubeadm and kubelet...\n"

# Check if crictl is already downloaded
if [ -d ${INSTALL_DIR}/crictl-$CRICTL_VERSION-linux-${ARCH} ]; then 
    echo "Proper crictl version already downloaded, skipping..." 
else 
    # Remove old crictl checksum file if it exists
    if [ -f ./crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz.sha256 ]; then 
        rm -f crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz.sha256
    fi

    # Download crictl
    echo -e "Downloading crictl...\n"
    curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz" 
    
    # Download crictl checksum file
    echo "Downloading crictl checksum..."
    curl -LO "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz.sha256"

    # Check the downloaded crictl file against the checksum
    echo "Checking crictl checksum..."
    CRICTL_CHECK="$(echo "$(cat crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz.sha256)  crictl" | sha256sum --check)"
    echo -e "$CRICTL_CHECK\n"

    # If the checksum is OK, download and extract crictl
    if [ "$CRICTL_CHECK" = "crictl: OK" ]; then 
        echo -e "SHA256SUM CHECK SUCCESSFUL. Downloading crictl...\n"
        sudo tar Cxzvf $INSTALL_DIR crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz
    else 
        echo -e "SHA256SUM CHECK FAILED. Please verify your download URLs for kubectl.\n" 
        exit 1
    fi
fi

# Change to the install directory
cd $INSTALL_DIR

# Download kubeadm and kubelet
echo -e "Downloading kubeadm and kubelet...\n"
sudo curl -L --remote-name-all https://dl.k8s.io/release/${K8S_RELEASE}/bin/linux/${ARCH}/{kubeadm,kubelet}
sudo chmod +x {kubeadm,kubelet}

# Download and configure the kubelet service
echo -e "Configuring kubelet service...\n"
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${KREL_VERSION}/cmd/krel/templates/latest/kubelet/kubelet.service" | sed "s:/usr/bin:${INSTALL_DIR}:g" | sudo tee ${SERVICE_DIR}/kubelet.service

# Create the kubelet service directory if it doesn't exist
if ! [ -f ${SERVICE_DIR}/kubelet.service.d ]; then 
    echo -e "Creating kubelet.service directory: ${SERVICE_DIR}/kubelet.service.d\n"
    sudo mkdir -p ${SERVICE_DIR}/kubelet.service.d 
fi

# Download and configure the kubeadm configuration
echo -e "Configuring kubeadm...\n"
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${KREL_VERSION}/cmd/krel/templates/latest/kubeadm/10-kubeadm.conf" | sed "s:/usr/bin:${INSTALL_DIR}:g" | sudo tee ${SERVICE_DIR}/kubelet.service.d/10-kubeadm.conf

echo -e "Kubeadm and Kubelet configured successfully.\n"




echo -e "Testing cluster resources...\n"

sudo kubectl version --client --output=yaml

echo -e "###End version output###\n\n"
sudo kubectl cluster-info

echo -e "###End cluster info###\n\n"
# Enable and start kubelet
echo -e "Enabling kubectl with systemctl...\n"
sudo systemctl enable --now kubelet

echo "====================== Kubernetes setup complete. Use kubectl to access... ======================"