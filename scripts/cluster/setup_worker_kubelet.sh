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

set -euo pipefail

STOCK_CONTAINERD=${1:-}

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT="$( cd "$DIR" && cd .. && cd .. && pwd)"


if [ "$STOCK_CONTAINERD" == "stock-only" ]; then
    CRI_SOCK="/run/containerd/containerd.sock"
else
    CRI_SOCK="/etc/vhive-cri/vhive-cri.sock"
fi

# Create kubelet service
cat << EOF | sudo sh -c 'cat > /etc/systemd/system/kubelet.service.d/0-containerd.conf'
[Service]
Environment="KUBELET_EXTRA_ARGS=--container-runtime=remote --runtime-request-timeout=15m --container-runtime-endpoint=unix://'${CRI_SOCK}'"
EOF

vhive_bin="${ROOT}/vhive"

cat << EOF | sudo sh -c 'cat > /etc/systemd/system/vhive@.service'
[Unit]
Description=vhive runtime
After=network.target local-fs.target firecracker-continerd

[Service]
ExecStartPre=sh -c "ip link set down br0; ip link set down br1; brctl delbr br0; brctl delbr br1 || true"
ExecStartPre=sh -c "rm /etc/vhive-cri/vhive-cri.sock || true"
ExecStart=sh -c "case "%I" in nosnaps) exec $vhive_bin ;; snaps) exec $vhive_bin -snapshots ;; upf) exec $vhive_bin -snapshots -upf ;; *) echo Invalid mode %I; exit 1 ;; esac"
Type=simple
Delegate=yes
KillMode=process
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now vhive\@nosnaps
