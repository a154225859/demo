#!/bin/bash

echo "Stop the existing ceremonyclient service"
systemctl stop ceremonyclient.service

sed -i 's|listenMultiaddr: /ip4/0.0.0.0/udp/8336/quic|listenMultiaddr: /ip4/0.0.0.0/tcp/8336|g' /root/ceremonyclient/node/.config/config.yml
sed -i 's|listenGrpcMultiaddr: ""|listenGrpcMultiaddr: "/ip4/0.0.0.0/tcp/8337"|g' /root/ceremonyclient/node/.config/config.yml
sed -i 's|listenRESTMultiaddr: ""|listenRESTMultiaddr: "/ip4/0.0.0.0/tcp/8338"|g' /root/ceremonyclient/node/.config/config.yml

sed -i '/export GOROOT=\/usr\/local\/go/d' ~/.bashrc
sed -i '/export GOPATH=\/root\/go/d' ~/.bashrc
sed -i '/export PATH=\$PATH:\/usr\/local\/go\/bin/d' ~/.bashrc

if grep -q 'export GOROOT=/usr/local/go' ~/.bashrc; then
    echo "GOROOT already set in ~/.bashrc."
else
    echo 'export GOROOT=/usr/local/go' >> ~/.bashrc
    echo "GOROOT set in ~/.bashrc."
fi

if grep -q "export GOPATH=$HOME/go" ~/.bashrc; then
    echo "GOPATH already set in ~/.bashrc."
else
    echo "export GOPATH=$HOME/go" >> ~/.bashrc
    echo "GOPATH set in ~/.bashrc."
fi

if grep -q 'export PATH=$GOPATH/bin:$GOROOT/bin:$PATH' ~/.bashrc; then
    echo "PATH already set in ~/.bashrc."
else
    echo 'export PATH=$GOPATH/bin:$GOROOT/bin:$PATH' >> ~/.bashrc
    echo "PATH set in ~/.bashrc."
fi

source ~/.bashrc

# 临时设置 Go 环境变量 - 解决一些奇怪的机器提示找不到go的问题
sleep 1
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH

go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest

# Navigate to the ceremonyclient directory and update the repository
cd /root/ceremonyclient && git remote set-url origin https://source.quilibrium.com/quilibrium/ceremonyclient.git && git fetch origin && git checkout release-cdn && git pull

# Extract version from Go file
version=$(cat /root/ceremonyclient/node/config/version.go | grep -A 1 "func GetVersion() \[\]byte {" | grep -Eo '0x[0-9a-fA-F]+' | xargs printf "%d.%d.%d")

# Determine binary path based on OS type and architecture
case "$OSTYPE" in
    linux-gnu*)
        if [[ $(uname -m) == x86* ]]; then
            binary="node-$version-linux-amd64"
        else
            binary="node-$version-linux-arm64"
        fi
        ;;
    darwin*)
        binary="node-$version-darwin-arm64"
        ;;
    *)
        echo "unsupported OS for releases, please build from source"
        exit 1
        ;;
esac

# 获取 CPU 核心数量并计算 CPUQuota
CPU_CORES=$(nproc)
CPU_QUOTA=$((CPU_CORES * 80))

echo "Create/update the systemd service file for ceremonyclient"
cat <<EOF > /lib/systemd/system/ceremonyclient.service
[Unit]
Description=Ceremony Client Go App Service

[Service]
CPUQuota=${CPU_QUOTA}%
Type=simple
Restart=always
RestartSec=5s
WorkingDirectory=/root/ceremonyclient/node
Environment=GOEXPERIMENT=arenas
ExecStart=/root/ceremonyclient/node/$binary

[Install]
WantedBy=multi-user.target
EOF

echo "Reload the systemd manager configuration"
systemctl daemon-reload

echo "Start the ceremonyclient service"
systemctl start ceremonyclient.service

echo "Ceremony Client has been updated and restarted successfully."
journalctl -fu ceremonyclient.service
