#!/bin/bash

# 确保脚本以 root 权限运行
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# 停止 ceremonyclient 服务
echo "Stopping Ceremony Client service..."
systemctl stop ceremonyclient.service

# 更新仓库
echo "Fetching latest updates from repository..."
cd /root/ceremonyclient
git fetch origin
git merge origin

# 清理 Go 编译缓存
echo "Cleaning Go build cache..."
cd /root/ceremonyclient/node
GOEXPERIMENT=arenas go clean -v -n -a ./...

# 删除旧的可执行文件
echo "Removing old executable..."
rm /root/go/bin/node

# 重新安装
echo "Reinstalling the node..."
GOEXPERIMENT=arenas go install ./...

# 重新启动服务
echo "Restarting Ceremony Client service..."
systemctl start ceremonyclient.service

echo "Ceremony Client has been updated and restarted successfully."

# 切换到客户端目录
cd /root/ceremonyclient/client

# 构建客户端
GOEXPERIMENT=arenas go build -o qclient main.go

echo "peerKey..."

# 执行客户端命令
./qclient cross-mint 0x7e1b9708c8a4c0ce46a6bc68aec71ad5244f60a6f5090e2b3a91d7c456c2e462d384a7ed312ad8a6915e2142834b38bffdfb000c

# 切换到节点目录
cd /root/ceremonyclient/node

echo "peerId..."

# 运行节点程序
GOEXPERIMENT=arenas go run ./... -peer-id
