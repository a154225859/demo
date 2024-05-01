#!/bin/bash

# 确保脚本以 root 权限运行
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# 创建并启用 swap 文件
echo "Creating and enabling swap file..."
mkdir /swap
fallocate -l 24G /swap/swapfile
chmod 600 /swap/swapfile
mkswap /swap/swapfile
swapon /swap/swapfile
echo '/swap/swapfile swap swap defaults 0 0' >> /etc/fstab

# 更新系统并安装基本工具
echo "Updating system and installing basic tools..."
apt -q update
apt-get install jq git screen -y

# 安装 Go
echo "Installing Go..."
wget https://golang.org/dl/go1.20.14.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.20.14.linux-amd64.tar.gz
rm go1.20.14.linux-amd64.tar.gz

# 配置 Go 环境变量
echo "Configuring Go environment variables..."
echo 'export GOROOT=/usr/local/go' >> ~/.bashrc
echo 'export GOPATH=$HOME/go' >> ~/.bashrc
echo 'export PATH=$GOPATH/bin:$GOROOT/bin:$PATH' >> ~/.bashrc

# 配置网络参数
echo "Configuring network parameters..."
echo 'net.core.rmem_max=600000000' >> /etc/sysctl.conf
echo 'net.core.wmem_max=600000000' >> /etc/sysctl.conf

# 配置网络参数
sysctl -p

# 配置 Go 环境变量
source ~/.bashrc

# 下载并初始化 ceremonyclient 仓库
echo "Cloning and setting up ceremonyclient repository..."
cd /root
git clone https://github.com/QuilibriumNetwork/ceremonyclient.git
cd /root/ceremonyclient/node

# 设置运行环境变量并运行应用，确保输入正确的 peer-id
echo "Starting the ceremonyclient node..."
GOEXPERIMENT=arenas go run ./...
