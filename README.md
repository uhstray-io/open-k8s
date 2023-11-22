- [Deploy High Availability Kubernetes Cluster Using Kubeadm on a Stack Control Plane](#deploy-high-availability-kuberenetes-cluster-using-kubeadm-on-a-stack-control-plane)
  - [Official Documentation](#official-documentation)
  - [Machine Preparation](#machine-preparation)
  - [Automatically prepare the machines using scripts](#automatically-prepare-the-machines-using-scripts)
  - [Manually Prepare Machines](#manually-prepare-machines)
    - [Essential Installations](#essential-installations)
      - [CNI Plugins: networking plugins used by Kubernetes.](#cni-plugins-networking-plugins-used-by-kubernetes)
      - [Setup Container Runtime Environments Kubernetes using containerd...](#setup-container-runtime-environments-kubernetes-using-containerd)
      - [Configure systemd as the cgroup driver for containerd](#configure-systemd-as-the-cgroup-driver-for-containerd)
      - [Install critcl for kubeadmin and CRI](#install-critcl-for-kubeadmin-and-cri)
    - [kubeadm: the command to bootstrap the cluster, kubelet: the component that runs on all of the machines in your cluster and does things like starting pods and containers](#kubeadm-the-command-to-bootstrap-the-cluster-kubelet-the-component-that-runs-on-all-of-the-machines-in-your-cluster-and-does-things-like-starting-pods-and-containers)
    - [kubectl: the command line util to talk to your cluster.](#kubectl-the-command-line-util-to-talk-to-your-cluster)
  - [Creating High Availability Kubernetes Cluster on a Stack Control Plane](#creating-high-availability-kubernetes-cluster-on-a-stack-control-plane)
    - [Setup HA Load Balancer using keepalived and HAProxy](#setup-ha-load-balancer-using-keepalived-and-haproxy)
    - [Control-Plane Node Initialization](#control-plane-node-initialization)
    - [Considerations about certifications, apiserver-advertise-addres, and ControlPlaneEndpoint](#considerations-about-certifications-apiserver-advertise-addres-and-controlplaneendpoint)
    - [CNI Networking Setup](#cni-networking-setup)
      - [Network Design Considerations](#network-design-considerations)
    - [Adding nodes to the cluster](#adding-nodes-to-the-cluster)
    - [(Optional) Proxying API Server to localhost](#optional-proxying-api-server-to-localhost)
      
# Deploy High Availability Kubernetes Cluster Using Kubeadm on a Stack Control Plane
## Official Documentation
- Refer to the [official kubeadm documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm) for detailed guidance.
- Refer to the [official kubernetes documentation](https://kubernetes.io/docs/home/) for kubernetes resources.

## Machine Preparation
- Start by understanding the [minimum requirements](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/) for a high-availability kubernetes cluster using [kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#before-you-begin)...
- Prepare Ubuntu 22.04 machines as described in the [deployment guide](https://github.com/uhstray-io/awx-operations/tree/main/deployments/ubuntu/22.04).
- Ensure all required [Kubernetes ports and protocols](https://kubernetes.io/docs/reference/networking/ports-and-protocols/) are open for both internal and external traffic.
- Follow the [Kubernetes services protocols](https://kubernetes.io/docs/reference/networking/service-protocols/) for proper configuration.

## Automatically prepare the machines using scripts
Find Kubernetes preparation scripts in the [\scripts](\scripts) directory:
- `controlplane-firewall.sh`
- `worker-firewall.sh`
- `prepare-k8s.sh`

Use can use these scripts and their variables to pre-configure your Ubuntu machines. Many of these scripts assume default ports and configurations for kubernetes.

## Manually Prepare Machines
### Essential Installations
- Install kubeadm, kubelet, and kubectl on all machines of your.
- You can use the --kubernetes-version flag to set the Kubernetes version to use. It is recommended that the versions of kubeadm, kubelet, kubectl and Kubernetes match.

#### CNI Plugins: networking plugins used by Kubernetes.
- Install CNI plugins from [here](https://github.com/containernetworking/plugins/releases). Use the script provided to download and extract the CNI plugins to the appropriate directory.
```bash
CNI_PLUGINS_VERSION="v1.3.0"
ARCH="amd64"
DEST="/opt/cni/bin"
sudo mkdir -p "$DEST"
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-${ARCH}-${CNI_PLUGINS_VERSION}.tgz" | sudo tar -C "$DEST" -xz
```

Set the download directory for the binaries
```bash
DOWNLOAD_DIR="/usr/local/bin"
sudo mkdir -p "$DOWNLOAD_DIR"
```
#### Setup Container Runtime Environments Kubernetes [using containerd...](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd)

- Set up container runtime environment with [containerd](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd).
- Download and extract `containerd` using the provided bash script.
- Configure systemd as the cgroup driver for containerd.

  Runtime	Path to Unix domain socket:
  * `containerd` |	`unix:///var/run/containerd/containerd.sock`

Download the container runtime `containerd` and extract it to the destination directory
```bash
DEST="/usr/local"
curl -L "https://github.com/containerd/containerd/releases/download/v2.0.0-beta.0/containerd-2.0.0-beta.0-linux-amd64.tar.gz" | sudo tar -C "$DEST" -xzvf
```

*Note:* Starting with v1.22 and later, when creating a cluster with kubeadm, if the user does not set the cgroupDriver field under KubeletConfiguration, kubeadm defaults it to systemd.

#### Configure systemd as the cgroup driver for [containerd](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd)

- You can find this file under the path /etc/containerd/config.toml.
- On Linux the default CRI socket for containerd is /run/containerd/containerd.sock

```bash
#Example Syntax for containerd
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
...
cgroupDriver: systemd
```

#### Install critcl for kubeadmin and CRI
- Install critcl using the provided script to aid with kubeadmin and CRI.
```bash
CRICTL_VERSION="v1.28.0"
ARCH="amd64"
curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz" | sudo tar -C $DOWNLOAD_DIR -xz
```

### kubeadm: the command to bootstrap the cluster, kubelet: the component that runs on all of the machines in your cluster and does things like starting pods and containers

Download the latest version of kubeadm and kubelet binaries

```bash
RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
ARCH="amd64"
RELEASE_VERSION="v0.16.2"

cd $DOWNLOAD_DIR
sudo chmod +x {kubeadm,kubelet}
sudo mkdir -p /etc/systemd/system/kubelet.service.d

sudo curl -L --remote-name-all https://dl.k8s.io/release/${RELEASE}/bin/linux/${ARCH}/{kubeadm,kubelet}
sudo curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/krel/templates/latest/kubelet/kubelet.service" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | sudo tee /etc/systemd/system/kubelet.service

sudo curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/krel/templates/latest/kubeadm/10-kubeadm.conf" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | sudo tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
```
### kubectl: the command line util to talk to your cluster.

Download the latest version of kubectl
```bash
sudo curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
```

Install kubectl
```bash
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

Check the client version and cluster response
```bash
kubectl version --client --output=yaml #client version
kubectl cluster-info #cluster response
```

Enable and start kubelet
```bash
sudo systemctl enable --now kubelet
```

## Creating High Availability Kubernetes Cluster on a Stack Control Plane

### Setup HA Load Balancer using [keepalived and HAProxy](https://github.com/kubernetes/kubeadm/blob/main/docs/ha-considerations.md#keepalived-and-haproxy)

- Set up an HA load balancer using [keepalived and HAProxy](https://github.com/kubernetes/kubeadm/blob/main/docs/ha-considerations.md#keepalived-and-haproxy).
- Configure keepalived and haproxy to run as static pods.

Refer to `/kubeadm`,`/kubeadm/control_a`, `/kubeadm/control_b`, and `/kubeadm/control_c/` for these files.

These files were built using these examples:

- [Archlinux Keepalived Example Configuration](https://wiki.archlinux.org/title/Keepalived)
- [Keepalived Syntax & Documentation : Global Definitions](https://keepalived.readthedocs.io/en/latest/configuration_synopsis.html#global-definitions-synopsis)
- [Example Keepalived Configurations](https://github.com/acassen/keepalived/tree/master/doc/samples)
- [kubeadm HA Docs](https://github.com/kubernetes/kubeadm/blob/main/docs/ha-considerations.md#bootstrap-the-cluster)

Test the node connection using
```bash
nc -v my.dns.name 6443
```

### Control-Plane Node Initialization
- Initialize the control-plane node as detailed in the [official documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/).
- Use `kubeadm init` with the `--control-plane-endpoint` flag to start the process.

You can review the docs for initializing and using kubeadm here: [Using Kubeadm to Create a Cluster](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)

Assuming that in a new cluster port 6443 is used for the load-balanced API Server and a virtual IP with the DNS name my.dns.name, an argument --control-plane-endpoint needs to be passed to kubeadm as follows:
```bash
sudo kubeadm init --control-plane-endpoint my.dns.name:6443 [additional arguments ...]
```

We should see an output similar to:
```bash
...
You can now join any number of control-plane node by running the following command on each as a root:

    kubeadm join 192.168.x.xxx:6443 --token {token} --discovery-token-ca-cert-hash sha256:{sha_token} --control-plane --certificate-key f8902e114ef118304e561c3ecd4d0b543adc226b7a07f675f56564185ffe0c07

Please note that the certificate-key gives access to cluster sensitive data, keep it secret!
As a safeguard, uploaded-certs will be deleted in two hours; If necessary, you can use kubeadm init phase upload-certs to reload certs afterward.

Then you can join any number of worker nodes by running the following on each as root:
    kubeadm join 192.168.x.xxx:6443 --token {token} --discovery-token-ca-cert-hash sha256:{sha_token}
```
Copy this output to a text file. You will use it later to join control plane and worker nodes to the cluster.

Test your kubectl with to see if the cluster responds:
```bash
kubectl get pod -n kube-system -w
```

### Considerations about certifications, apiserver-advertise-addres, and ControlPlaneEndpoint

- `--apiserver-advertise-address` can be used to set the advertise address for this particular control-plane node's API server
- `--control-plane-endpoint=my.dns.name` can be used to set the shared endpoint for all control-plane nodes.
- kubeadm tries to detect the container runtime automatically. To use containerd we can specify the `--cri-socket argument` to kubeadm.
- Use the `--upload-certs` flag with `kubeadm init` for easier certificate management across control plane nodes.
- For accessing the API Server externally, use `kubectl proxy`.

To re-upload the certificates and generate a new decryption key, use the following command on a control plane node that is already joined to the cluster:
```bash
sudo kubeadm init phase upload-certs `--upload-certs`
```
You can also specify a custom `--certificate-key` during init that can later be used by join. To generate such a key you can use the following command:
```bash
kubeadm certs certificate-key
```
The certificate key is a hex encoded string that is an AES key of size 32 bytes.

Note: The kubeadm-certs Secret and the decryption key expire after two hours.
Caution: As stated in the command output, the certificate key gives access to cluster sensitive data, keep it secret!

### CNI Networking Setup
- Apply the chosen CNI plugin following the provided instructions.
- Ensure the network plugin is compatible with your cluster's configuration.
- To add a pod CIDR pass the flag `--pod-network-cidr`, or if you are using a kubeadm configuration file set the podSubnet field under the networking object of ClusterConfiguration.

#### Network Design Considerations

Reference: 
- https://kubernetes.io/docs/concepts/services-networking/
  - https://github.com/containernetworking/cni
  - https://github.com/containerd/containerd/blob/main/script/setup/install-cni 
  - https://kubernetes.io/docs/concepts/cluster-administration/networking/
- https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/
  - https://github.com/ovn-org/ovn-kubernetes/
  - https://kubernetes.io/docs/concepts/services-networking/gateway/
  - https://github.com/kubernetes/dashboard#kubernetes-dashboard
  - https://kubernetes.io/docs/tasks/administer-cluster/coredns/
  - https://doc.traefik.io/traefik/providers/kubernetes-ingress/

You can install a Pod network add-on with the following command on the control-plane node or a node that has the kubeconfig credentials:

```bash
kubectl apply -f <add-on.yaml>
```
Note: The kubeadm init flags `--config` and `--certificate-key` cannot be mixed, therefore if you want to use the kubeadm configuration you must add the certificateKey field in the appropriate config locations (under InitConfiguration and JoinConfiguration: controlPlane).


### Adding nodes to the cluster
- Add additional control-plane nodes and worker nodes using the `kubeadm join` command as described in the output of the `kubeadm init` command.
- Follow the detailed steps for adding nodes to ensure proper cluster configuration.

Execute the join command that was previously given to you by the kubeadm init output on the first node. It should look something like this:
```bash
sudo kubeadm join 192.168.x.xxx:6443 --token {token} --discovery-token-ca-cert-hash sha256:{sha_token} --control-plane --certificate-key {certificate_key}
```
- The --control-plane flag tells kubeadm join to create a new control plane.
- The --certificate-key ... will cause the control plane certificates to be downloaded from the kubeadm-certs Secret in the cluster and be decrypted using the given key.
  
You can join multiple control-plane nodes in parallel.

Turning a single control plane cluster created without --control-plane-endpoint into a highly available cluster is not supported by kubeadm

For more initialization options, view the [kubeadm docs](https://kubernetes.io/docs/reference/setup-tools/kubeadm/)


### (Optional) Proxying API Server to localhost 
If you want to connect to the API Server from outside the cluster you can use kubectl proxy:
```bash
/etc/kubernetes/admin.conf .
kubectl --kubeconfig ./admin.conf proxy
```
You can now access the API Server locally at http://localhost:8001/api/v1
