#!/bin/bash

# 创建并启用 swap 文件
sudo mkdir /swap
sudo fallocate -l 24G /swap/swapfile
sudo chmod 600 /swap/swapfile
sudo mkswap /swap/swapfile
sudo swapon /swap/swapfile
echo '/swap/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab

# 更新系统并安装基本工具
sudo apt -q update
sudo apt-get install jq git screen -y

# 安装 Go
wget https://golang.org/dl/go1.20.14.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.20.14.linux-amd64.tar.gz
rm go1.20.14.linux-amd64.tar.gz

# 配置 Go 环境变量
echo 'export GOROOT=/usr/local/go' >> ~/.bashrc
echo 'export GOPATH=$HOME/go' >> ~/.bashrc
echo 'export PATH=$GOPATH/bin:$GOROOT/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# 配置网络参数
echo 'net.core.rmem_max=600000000' | sudo tee -a /etc/sysctl.conf
echo 'net.core.wmem_max=600000000' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# 下载 cereumonyclient 仓库
git clone https://github.com/QuilibriumNetwork/ceremonyclient.git
cd ceremonyclient/node
./poor_mans_cd.sh
