# Setup Microk8s on Ubuntu 22.04 with Traefik Ingress, Cert-Manager and Kubernetes Dashboard

## Installing Microk8s
https://microk8s.io/docs/getting-started

Channel 1.27 is the latest stable version of Microk8s that works with the kubernetes dashboard and gpu scheduling at the time of writing this document

```bash
sudo snap install microk8s --classic --channel=1.27
```

Output:
```bash
From the node you wish to join to this cluster, run the following:
microk8s join 192.168.1.1:25000/201d90539d3fcaa0391502feeb947e1f/ef3f81cead89

Use the '--worker' flag to join a node as a worker not running the control plane, eg:
microk8s join 192.168.1.1:25000/201d90539d3fcaa0391502feeb947e1f/ef3f81cead89 --worker

If the node you are adding is not reachable through the default interface you can use one of the following:
microk8s join 192.168.1.1:25000/201d90539d3fcaa0391502feeb947e1f/ef3f81cead89
microk8s join fdcd:620f:92d4:e5f4:d6ae:52ff:fea6:2c8:25000/201d90539d3fcaa0391502feeb947e1f/ef3f81cead89
```

How to restart microk8s

```bash
sudo systemctl restart microk8s
```

Changing versions of microk8s installed

```bash
sudo snap refresh microk8s --classic --channel=1.27
```

## Setting up the microk8s user permissions

https://microk8s.io/docs/multi-user

To use the community maintained flavor enable the respective repository:

```bash
microk8s enable community
```
Output:
```bash
Infer repository core for addon community
Cloning into '/var/snap/microk8s/common/addons/community'...
done.
Community repository is now enabled
```

## Testing Traefik Ingress Controller

```bash
microk8s enable traefik
```

Output:
```bash
Enabling traefik ingress controller

Traefik Ingress controller 20.8.0 has been installed. Next, you can start
creating Ingress resources to access your services. Useful commands:

1. Get the external IP of the LoadBalancer service.

    $ microk8s kubectl get service -n traefik traefik

2. If your cluster cannot provision LoadBalancer services, you can also use the NodePort service.

    $ microk8s kubectl get service -n traefik traefik-ingress-service

3. Access the Traefik Web UI at http://localhost:18080

    $ microk8s kubectl port-forward -n traefik traefik-web-ui 18080:8080
```

## Microk8s ports and services

https://microk8s.io/docs/services-and-ports

Easy commands to setup the required ports for microk8s
```bash
sudo ufw allow 16443,10250,10255,25000,12379,10257,10259,19001/tcp
sudo ufw allow 16443,10250,10255,25000,12379,10257,10259,19001/udp

sudo ufw allow 4789/udp

sudo ufw allow 10248,10249,10251,10256,2380,1338/tcp
sudo ufw allow 10248,10249,10251,10256,2380,1338/udp

sudo ufw allow 6443,443,80/tcp
```

Add the microk8s kubectl to the .bashrc file for your user
```bash
sudo nano .bashrc
```
Then add the following line to the end of the file
```bash
alias kubectl='microk8s kubectl'
```

for traefik
```bash
sudo ufw allow 18080
sudo ufw allow 8080
```

## Enabled cert-manager

===========================

Cert-manager is installed. As a next step, try creating a ClusterIssuer
for Let's Encrypt by creating the following resource:

```bash
microk8s kubectl apply -f - <<EOF
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    # You must replace this email address with your own.
    # Let's Encrypt will use this to contact you about expiring
    # certificates, and issues related to your account.
    email: me@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      # Secret resource that will be used to store the account's private key.
      name: letsencrypt-account-key
    # Add a single challenge solver, HTTP01 using nginx
    solvers:
    - http01:
        ingress:
          class: public
EOF
```

Then, you can create an ingress to expose 'my-service:80' on 'https://my-service.example.com' with:
```bash
microk8s enable ingress
microk8s kubectl create ingress my-ingress \
--annotation cert-manager.io/cluster-issuer=letsencrypt \
--rule 'my-service.example.com/*=my-service:80,tls=my-service-tls'
```

Setup microk8s dashboard TLS
```bash
microk8s kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
 name: kubernetes-dashboard
 annotations:
   cert-manager.io/cluster-issuer: lets-encrypt
spec:
 tls:
 - hosts:
   - kube.uhstray.io
   secretName: kubernetes-dashboard-ingress-tls
 rules:
 - host: kube.uhstray.io
   http:
     paths:
     - backend:
         service:
           name: kubernetes-dashboard
           port:
             number: 8443
       path: /
       pathType: Exact
EOF
```


kubernetes dashboard

sudo snap install helm --classic

microk8s kubectl config fix

microk8s kubectl config view --raw > ~/.kube/config

helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/

curl -LO https://github.com/kubernetes/dashboard/raw/master/charts/helm-chart/kubernetes-dashboard/values.yaml

helm install dashboard kubernetes-dashboard/kubernetes-dashboard --namespace kubernetes-dashboard -f kube-dashboard-values.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v3.0.0-alpha0/charts/kubernetes-dashboard.yaml


microk8s kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443 &

#WARNING:  IPtables FORWARD policy is DROP. Consider enabling traffic forwarding with: sudo iptables -P FORWARD ACCEPT

sudo iptables -P FORWARD ACCEPT

sudo ufw allow 8443

kubectl get services -n kubernetes-dashboard

helm delete kubernetes-dashboard --namespace kubernetes-dashboard





error: resource mapping not found for name: "selfsigned" namespace: "kubernetes-dashboard" from "https://raw.githubusercontent.com/kubernetes/dashboard/v3.0.0-alpha0/charts/kubernetes-dashboard.yaml": no matches for kind "Issuer" in version "cert-manager.io/v1"
ensure CRDs are installed first

kubectl label namespace cert-manager cert-manager.io/disable-validation=true



kubectl apply -f - <<EOF
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  namespace: kubernetes-dashboard
  name: kubernetes-dashboard-ingress
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    cert-manager.io/cluster-issuer: "letsencrypt"
spec:
  ingressClassName: nginx-dashboard
  tls:
  - hosts:
    - kube.uhstray.io
    secretName: kubernetes-dashboard-cert
  rules:
  - host: kube.uhstray.io
    http:
      paths:
      - path: /
        backend:
          serviceName: kubernetes-dashboard
          servicePort: 8443
EOF



microk8s kubectl create ingress kubernetes-dashboard \
    --annotation cert-manager.io/cluster-issuer=letsencrypt \
    --rule 'kube.uhstray.io/*=kube-dashboard:8443,tls=kube-dashboard-tls'




