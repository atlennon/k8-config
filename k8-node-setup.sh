#!/bin/bash
#Add keys and repos
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list
apt-get update && apt-get install -y apt-transport-https gnupg2
#Install Docker CE and Kubernetes
apt-get install -y docker-ce=18.06.1~ce~3-0~ubuntu kubelet=1.15.2-00 kubeadm=1.15.2-00 kubectl=1.15.2-00
#apt-get install -y docker-ce kubelet kubeadm kubectl
#hold package versions
apt-mark hold docker-ce kubelet kubeadm kubectl
#Set up the Docker daemon
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
mkdir -p /etc/systemd/system/docker.service.d
#Restart Docker
systemctl daemon-reload
systemctl restart docker
#Configure IP Tables
echo "net.bridge.bridge-nf-call-iptables=1" | tee -a /etc/sysctl.conf
modprobe br_netfilter
sysctl -p
#set hostname to fqdn
hostnamectl set-hostname $(curl http://169.254.169.254/latest/meta-data/local-hostname)
#set cluster vars
MASTER_ADDR=ip-10-1-1-9.us-west-2.compute.internal:6443
TOKEN=9caxg2.n4r7abi34ammvo2h
CA_CERT_HASH=sha256:ffcd0786762f6d9390ebd3b8b95f98c6d65df7ff2f959d856419ecc149cbecd0
cat << EOF > /etc/kubernetes/node.yaml
apiVersion: kubeadm.k8s.io/v1beta2
kind: JoinConfiguration
discovery:
 bootstrapToken:
   token: $TOKEN
   apiServerEndpoint: $MASTER_ADDR
   caCertHashes:
     - $CA_CERT_HASH
nodeRegistration:
 kubeletExtraArgs:
   cloud-provider: aws
EOF
#join the cluster
#kubeadm join $MASTER_ADDR --token $TOKEN --discovery-token-ca-cert-hash $CA_CERT_HASH --kubelet-extra-args 'cloud-provider=aws'
kubeadm join --config /etc/kubernetes/node.yaml