#!/bin/bash

# MIT License
#
# Copyright (c) 2020 Dmitrii Ustiugov, Plamen Petrov and EASE lab
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -xeuo pipefail

sudo apt-get update >> /dev/null

sudo apt-get -y install btrfs-progs pkg-config libseccomp-dev unzip tar libseccomp2 socat util-linux apt-transport-https curl ipvsadm >> /dev/null
sudo apt-get -y install apparmor apparmor-utils >> /dev/null        # needed for containerd versions >1.5.x

wget --continue --quiet https://github.com/protocolbuffers/protobuf/releases/download/v3.19.4/protoc-3.19.4-linux-x86_64.zip
sudo unzip -o -q protoc-3.19.4-linux-x86_64.zip -d /usr/local

containerd_version=1.6.2
wget --continue --quiet https://github.com/containerd/containerd/releases/download/v$containerd_version/containerd-${containerd_version}-linux-amd64.tar.gz
sudo tar -C /usr/local -xzf containerd-${containerd_version}-linux-amd64.tar.gz
wget --quiet https://raw.githubusercontent.com/containerd/containerd/v${containerd_version}/containerd.service -O - | \
	sudo sh -c "cat > /etc/systemd/system/containerd.service"
sudo systemctl daemon-reload
sudo systemctl enable --now containerd

wget --continue --quiet https://github.com/opencontainers/runc/releases/download/v1.1.0/runc.amd64
mv runc.amd64 runc
sudo install -D -m0755 runc /usr/local/sbin/runc

wget --continue --quiet https://storage.googleapis.com/gvisor/releases/release/20210622/x86_64/runsc 
sudo chmod a+rx runsc
sudo mv runsc /usr/local/bin

containerd --version || echo "failed to build containerd"


# Install k8s
K8S_VERSION=1.25.3-00
sudo sh -c "echo 'deb [trusted=yes] http://apt.kubernetes.io/ kubernetes-xenial main' > /etc/apt/sources.list.d/kubernetes.list"
sudo apt-get update >> /dev/null
sudo apt-get -y install cri-tools ebtables ethtool kubeadm=$K8S_VERSION kubectl=$K8S_VERSION kubelet=$K8S_VERSION kubernetes-cni >> /dev/null
sudo apt-mark hold kubeadm kubectl kubelet

# Install knative CLI
KNATIVE_VERSION="release-1.9"
git clone --quiet --depth=1 --branch=$KNATIVE_VERSION -c advice.detachedHead=false https://github.com/knative/client.git $HOME/client

cd $HOME/client
# Required by build.sh script
sudo apt-get install -y file
hack/build.sh -f
sudo mv kn /usr/local/bin


# Necessary for containerd as container runtime but not docker
sudo tee /etc/modules-load.d/vhive.conf <<EOF
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Set up required sysctl params, these persist across reboots.
sudo tee /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --quiet --system
