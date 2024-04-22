# Getting Started

- [Setup the firewall and network rules](#setup-the-firewall-and-network-rules)
- [Prepare a cluster using k0sctl and k0s on Ubuntu 22.04](#prepare-a-cluster-using-k0sctl-and-k0s-on-ubuntu-2204)
- [Manually Prepare High-Availability k0s Cluster on Ubuntu 22.04](#manually-prepare-high-availability-k0s-cluster-on-ubuntu-2204)
- [Test the cluster and your connection](#test-the-cluster-and-your-connection)
 
Choose which what you'd like to install k0s. Be sure to complete the directions below before setting moving into the cluster setup and configuration.

## Preparing Ubuntu 22.04 Machines with Cloud-Init

- https://cloud-init.io/
- https://github.com/canonical/cloud-init
- https://www.digitalocean.com/community/tutorials/how-to-use-cloud-config-for-your-initial-server-setup
- https://cloudinit.readthedocs.io/en/latest/reference/examples.html

## Setup the firewall and network rules

Required ports and protocols for k0s

| Protocol |	Port |	Service |	Direction |	Notes |
|---|---|---|---|---|
| TCP |	2380 | etcd peers | controller <-> controller | |	
| TCP	| 6443 |	kube-apiserver	| worker, CLI => controller	| Authenticated Kube API using Kube TLS client certs, ServiceAccount tokens with RBAC |
| TCP |	179 |	kube-router |	worker <-> worker |	BGP routing sessions between peers |
| UDP	| 4789 |	Calico |	worker <-> worker |	Calico VXLAN overlay
| TCP |	10250 |	kubelet |	controller, worker => host * |	Authenticated kubelet API for the controller node kube-apiserver (and heapster/metrics-server addons) using TLS client certs |
| TCP	| 9443	| k0s-api	| controller <-> controller | 	k0s controller join API, TLS with token auth |
| TCP	| 8132	| konnectivity | worker <-> controller | Konnectivity is used as "reverse" tunnel between kube-apiserver and worker kubelets |
| TCP	 | 112 |	keepalived |	controller <-> controller	| Only required for control plane load balancing vrrpInstances for ip address 224.0.0.18. 224.0.0.18 is a multicast IP address defined in RFC 3768. |

Controller Firewall Rules:

```bash
LOCAL_NETWORK="192.168.1.0/24"

sudo ufw allow from $LOCAL_NETWORK proto tcp to any port 22  # SSH

# Controller Node Ports
sudo ufw allow 2380/tcp  # etcd peers
sudo ufw allow 6443/tcp  # kube-apiserver
sudo ufw allow 30000:32767/tcp
sudo ufw allow 10250/tcp  # kubelet
sudo ufw allow 9443/tcp  # k0s-api
sudo ufw allow 8132:8133/tcp  # konnectivity
sudo ufw allow 112/tcp  # keepalived
```

Worker Firewall Rules:

```bash
LOCAL_NETWORK="192.168.1.0/24"

sudo ufw allow from $LOCAL_NETWORK proto tcp to any port 22  # SSH

# Worker Node Ports
sudo ufw allow 6443/tcp  # kube-apiserver
sudo ufw allow 179/tcp # kube-router
sudo ufw allow 4789/udp # Calico
sudo ufw allow 10250/tcp  # kubelet
sudo ufw allow 8132:8133/tcp  # konnectivity
```

---

# Prepare a cluster using k0sctl and k0s on Ubuntu 22.04
- [Getting Started](#getting-started)
  - [Preparing Ubuntu 22.04 Machines with Cloud-Init](#preparing-ubuntu-2204-machines-with-cloud-init)
  - [Setup the firewall and network rules](#setup-the-firewall-and-network-rules)
- [Prepare a cluster using k0sctl and k0s on Ubuntu 22.04](#prepare-a-cluster-using-k0sctl-and-k0s-on-ubuntu-2204)
  - [Pre-requisites](#pre-requisites)
  - [Install Homebrew](#install-homebrew)
  - [Install k0sctl](#install-k0sctl)
    - [Create the SSH keys and copy them to your machines](#create-the-ssh-keys-and-copy-them-to-your-machines)
    - [Create a k0sctl configuration file and initialize the cluster](#create-a-k0sctl-configuration-file-and-initialize-the-cluster)
- [Manually Prepare High-Availability k0s Cluster on Ubuntu 22.04](#manually-prepare-high-availability-k0s-cluster-on-ubuntu-2204)
  - [Installing k0s](#installing-k0s)
  - [Adding a Worker Node to the Cluster](#adding-a-worker-node-to-the-cluster)
  - [Adding a Control-Plane Node to the Cluster](#adding-a-control-plane-node-to-the-cluster)
  - [Check and access the cluster](#check-and-access-the-cluster)
  - [Configure High Availability for k0s using traefik and metallb](#configure-high-availability-for-k0s-using-traefik-and-metallb)
  - [Configure High Availability for k0s using k0s resources](#configure-high-availability-for-k0s-using-k0s-resources)
- [Test the cluster and your connection](#test-the-cluster-and-your-connection)

## Pre-requisites

Original documentation
- https://docs.k0sproject.io/stable/k0sctl-install/

k0sctl GitHub Project
- https://github.com/k0sproject/k0sctl

k0s Install Requirements
- https://docs.k0sproject.io/stable/system-requirements/

Homebrew Repository
- https://brew.sh/

## Install Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

```bash
(echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"') >> /home/user/.bashrc
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
```

## Install k0sctl

```bash
DISABLE_TELEMETRY=true
brew install k0sproject/tap/k0sctl
```

### Create the SSH keys and copy them to your machines

To create a new key enter, and then input the filename and passphrase if desired:

```bash
ssk-keygen -t rsa -b 2048
```

**From there you can...**

- Upload your key to the target server:

```bash
ssh-copy-id -i ~/.ssh/id_rsa user@192.168.1.100
```

- Send the files from your local machine to the server:
```bash
scp -i "s/home/user/FILENAME" "~/.ssh/id_rsa.pub" user@192.168.1.100:/home/user/.ssh/FILENAME
```

- Pull the files from another machine to the server:
```bash
scp -i ~/.ssh/id_rsa.pub user@192.168.1.100:/home/user/.ssh/FILENAME /home/user/FILENAME
```

Update the sudo permissions for the user:

```bash
sudo visudo
```

Add the following line to the file:

```bash
user ALL=(ALL) NOPASSWD: ALL
%uberpw ALL=(ALL) NOPASSWD: ALL
```

Add the user to the sudoers group:

```bash
sudo usermod -aG sudo <user>
sudo usermod -aG uberpw <user>
```

### Create a k0sctl configuration file and initialize the cluster

Run the following command to generate a k0sctl configuration file:
```bash
k0sctl init 192.168.1.50 192.168.1.51 192.168.1.52 192.168.1.53 192.168.1.54 --k0s > k0sctl.yaml
```
Be sure to update the file with any necessary configuration changes.

Apply the configuration to the cluster:
```bash
k0sctl apply --config -
# OR
k0sctl apply --config path/to/k0sctl.yaml
```

Config editing resources:
- https://docs.k0sproject.io/main/networking/
- https://docs.k0sproject.io/main/configuration/
- https://docs.k0sproject.io/main/dynamic-configuration/
- https://github.com/k0sproject/k0sctl?tab=readme-ov-file#configuration-file

---

# Manually Prepare High-Availability k0s Cluster on Ubuntu 22.04

- [Getting Started](#getting-started)
  - [Preparing Ubuntu 22.04 Machines with Cloud-Init](#preparing-ubuntu-2204-machines-with-cloud-init)
  - [Setup the firewall and network rules](#setup-the-firewall-and-network-rules)
- [Prepare a cluster using k0sctl and k0s on Ubuntu 22.04](#prepare-a-cluster-using-k0sctl-and-k0s-on-ubuntu-2204)
  - [Pre-requisites](#pre-requisites)
  - [Install Homebrew](#install-homebrew)
  - [Install k0sctl](#install-k0sctl)
    - [Create the SSH keys and copy them to your machines](#create-the-ssh-keys-and-copy-them-to-your-machines)
    - [Create a k0sctl configuration file and initialize the cluster](#create-a-k0sctl-configuration-file-and-initialize-the-cluster)
- [Manually Prepare High-Availability k0s Cluster on Ubuntu 22.04](#manually-prepare-high-availability-k0s-cluster-on-ubuntu-2204)
  - [Installing k0s](#installing-k0s)
  - [Adding a Worker Node to the Cluster](#adding-a-worker-node-to-the-cluster)
  - [Adding a Control-Plane Node to the Cluster](#adding-a-control-plane-node-to-the-cluster)
  - [Check and access the cluster](#check-and-access-the-cluster)
  - [Configure High Availability for k0s using traefik and metallb](#configure-high-availability-for-k0s-using-traefik-and-metallb)
  - [Configure High Availability for k0s using k0s resources](#configure-high-availability-for-k0s-using-k0s-resources)
- [Test the cluster and your connection](#test-the-cluster-and-your-connection)

k0s Requirements
- https://docs.k0sproject.io/stable/system-requirements/

- https://docs.k0sproject.io/stable/high-availability/
  
- https://k0sproject.io/

- https://github.com/k0sproject/k0s

- https://docs.k0sproject.io/stable/helm-charts/

## Installing k0s

https://k0sproject.io/docs/installation/

Acceptable flags for k0s download script.

```bash
curl -sSLf https://get.k0s.sh | sudo K0S_VERSION=v1.29.2+k0s.0 DEBUG=true sh
```

```bash
curl -sSLf https://get.k0s.sh | sudo sh
```

Bootstrap a k0s cluster.

```bash
mkdir -p /etc/k0s
k0s config create > /etc/k0s/k0s.yaml
```

Config documentation: https://docs.k0sproject.io/stable/configuration/


Install the controller and start.

```bash
sudo k0s install controller -c /etc/k0s/k0s.yaml
sudo k0s start
```

## Adding a Worker Node to the Cluster

Create a token to add a worker node.

```bash
sudo k0s token create --role=worker
```

Name this token, worker.yaml, and save it to a file.

Copy the token from your control plane machine to your worker node.

You need the ssh key for the worker node on your control plane machine.
```bash
scp -i ~/.ssh/id_rsa.pub worker.yaml user@192.168.1.51:/home/user/worker.yaml
```

On the worker node, install k0s as a worker.
```bash
sudo k0s install worker --token-file /path/to/token/file
```

Start the worker node.
```bash
sudo k0s start
```

## Adding a Control-Plane Node to the Cluster

Note: Either etcd or an external data store (MySQL or Postgres) via kine must be in use to add new controller nodes to the cluster. Pay strict attention to the [high availability configuration](https://docs.k0sproject.io/stable/high-availability/) and make sure the configuration is identical for all controller nodes.

To create a join token for the new controller, run the following command on an existing controller:

```bash
sudo k0s token create --role=controller --expiry=1h > token-file
```

On the new controller, run:

```bash
sudo k0s install controller --token-file /path/to/token/file -c /etc/k0s/k0s.yaml
```

Start the new controller.
```bash
sudo k0s start
```

## Check and access the cluster

To get general information about your k0s instance's status:

```bash
sudo k0s status
```

Use the Kubernetes 'kubectl' command-line tool that comes with k0s binary to deploy your application or check your node status:

```bash
sudo k0s kubectl get nodes
```

Check or copy the kubeconfig file 

```bash
sudo cat /var/lib/k0s/pki/admin.conf
```

## Configure High Availability for k0s using traefik and metallb

Update your k0s.yaml file to include the following:

```yaml
extensions:
  helm:
    repositories:
    - name: traefik
      url: https://traefik.github.io/charts
    - name: bitnami
      url: https://charts.bitnami.com/bitnami
    charts:
    - name: traefik
      chartname: traefik/traefik
      version: "20.5.3"
      namespace: default
    - name: metallb
      chartname: bitnami/metallb
      version: "2.5.4"
      namespace: default
      values: |
        configInline:
          address-pools:
          - name: generic-cluster-pool
            protocol: layer2
            addresses:
            - 192.168.1.35-192.168.1.38
```

Get the Load Balancer IP

```bash
kubectl get all
```

```bash
NAME                         TYPE           CLUSTER-IP       EXTERNAL-IP      PORT(S)                      AGE
service/kubernetes           ClusterIP      10.96.0.1        <none>           443/TCP                      96s
service/traefik-1607085579   LoadBalancer   10.105.119.102   192.168.0.5      80:32153/TCP,443:30791/TCP   84s
```

Create a traefik-dashboard.yaml file by running the following command:

```yaml
kubectl apply -f traefik-dashboard.yaml
```

## Configure High Availability for k0s using k0s resources

You can create high availability for the control plane by distributing the control plane across multiple nodes and installing a load balancer on top. Etcd can be colocated with the controller nodes (default in k0s) to achieve highly available datastore at the same time.

Load Balancer
Control plane high availability requires a tcp load balancer, which acts as a single point of contact to access the controllers. The load balancer needs to allow and route traffic to each controller through the following ports:

6443 (for Kubernetes API)
8132 (for Konnectivity)
9443 (for controller join API)
The load balancer can be implemented in many different ways and k0s doesn't have any additional requirements. You can use for example HAProxy, NGINX or your cloud provider's load balancer.

k0s configuration#
First and foremost, all controllers should utilize the same CA certificates and SA key pair:

/var/lib/k0s/pki/ca.key
/var/lib/k0s/pki/ca.crt
/var/lib/k0s/pki/sa.key
/var/lib/k0s/pki/sa.pub
/var/lib/k0s/pki/etcd/ca.key
/var/lib/k0s/pki/etcd/ca.crt
To generate these certificates, you have two options: either generate them manually using the instructions for installing custom CA certificates, and then share them between controller nodes, or use k0sctl to generate and share them automatically.

The second important aspect is: the load balancer address must be configured to k0s either by using k0s.yaml or by using k0sctl to automatically deploy all controllers with the same configuration:

Configuration using k0s.yaml (for each controller)#
Note to update your load balancer's public ip address into two places.

spec:
  api:
    externalAddress: <load balancer public ip address>
    sans:
    - <load balancer public ip address>
Configuration using k0sctl.yaml (for k0sctl)#
Add the following lines to the end of the k0sctl.yaml. Note to update your load balancer's public ip address into two places.

  k0s:
    config:
      spec:
        api:
          externalAddress: <load balancer public ip address>
          sans:
          - <load balancer public ip address>

---

# Test the cluster and your connection

Start or stop the cluster:
```bash
sudo k0s start
sudo k0s stop
```

Reset the cluster and its resources:
```bash
sudo k0s reset
```

Get the kubeconfig from the cluster:
```bash
k0sctl kubeconfig --config path/to/k0sctl.yaml > k0s.config
kubectl get node --kubeconfig k0s.config
```

Edit the k0s config
```bash
k0s config edit
```

Check your iptables are properly configured:

```bash
nsenter -t $(pidof -s kuberouter) -m iptables -V #for kube-router
nsenter -t $(pidof -s calico-node) -m iptables -V #for calico
```