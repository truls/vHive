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

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT="$( cd $DIR && cd .. && cd .. && pwd)"
SCRIPTS=$ROOT/scripts

SANDBOX=${1:-}
USE_STARGZ=${2:-}

if [ -z "$SANDBOX" ]; then
    SANDBOX="firecracker"
fi

if [ "$SANDBOX" != "gvisor" ] && [ "$SANDBOX" != "firecracker" ] && [ "$SANDBOX" != "stock-only" ]; then
    echo Specified sanboxing technique is not supported. Possible are \"stock-only\", \"firecracker\" and \"gvisor\"
    exit 1
fi

$SCRIPTS/utils/disable_auto_updates.sh

source $SCRIPTS/install_go.sh
$SCRIPTS/setup_system.sh

sudo mkdir -p /etc/vhive-cri

if [ "$SANDBOX" == "firecracker" ]; then
    sudo install -m755 $SCRIPTS/create_devmapper.sh /usr/local/bin/vhive_setup_devmapper.sh
    cat << EOF | sudo sh -c "cat > /etc/systemd/system/vhive-devmapper.service"
[Unit]
Description=vhive devmapper setup for firecracker-containerd

[Service]
Type=oneshot
ExecStart=/usr/local/bin/vhive_setup_devmapper.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable --now vhive-devmapper

    $SCRIPTS/setup_firecracker_containerd.sh
fi

if [ "$SANDBOX" == "gvisor" ]; then
    $SCRIPTS/setup_gvisor_containerd.sh
fi

$SCRIPTS/install_stock.sh


if [ "$USE_STARGZ" == "use-stargz" ]; then
    $SCRIPTS/stargz/setup_stargz.sh
fi
