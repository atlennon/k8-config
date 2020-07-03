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
# Setup Network with AWS provider
cat << EOF > /etc/kubernetes/aws.yaml  
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
networking:
  serviceSubnet: "10.100.0.0/16"
  podSubnet: "10.244.0.0/16"
apiServer:
  extraArgs:
    cloud-provider: "aws"
controllerManager:
  extraArgs:
    cloud-provider: "aws"
EOF
#set hostname to fqdn
hostnamectl set-hostname $(curl http://169.254.169.254/latest/meta-data/local-hostname)
#init cluster
#kubeadm init --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors=NumCPU
kubeadm init --config /etc/kubernetes/aws.yaml --ignore-preflight-errors=NumCPU
#configure kubectl for root and ubuntu user
mkdir -p $HOME/.kube
cp /etc/kubernetes/admin.conf $HOME/.kube/config
mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config
#configure autocompletion
echo 'source <(kubectl completion bash)' >>~/.bashrc
kubectl completion bash >/etc/bash_completion.d/kubectl
#install flannel
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
#export KUBEJOIN=$(kubeadm token create --print-join-command)
