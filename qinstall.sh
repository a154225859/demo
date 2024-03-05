#!/bin/bash

# 检查是否为root用户
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# 创建挂载点
mkdir -p /quilibrium

# 检查UUID并保存到变量中
UUID=$(blkid -o value -s UUID /dev/vdb1)

# 挂载磁盘
mount /dev/vdb1 /quilibrium

# 检查/etc/fstab中是否已有相应条目，避免重复添加
if grep -qs '/quilibrium ' /etc/fstab; then
   echo "/quilibrium already exists in /etc/fstab"
else
   # 更新/etc/fstab以实现自动挂载
   echo "UUID=$UUID /quilibrium ext4 defaults 0 2" >> /etc/fstab
   echo "/dev/vdb1 is now set to auto-mount to /quilibrium"
fi

# 测试fstab配置并重新挂载
mount -a

# 创建并启用 swap 文件
sudo mkdir /swap
sudo fallocate -l 24G /swap/swapfile
sudo chmod 600 /swap/swapfile
sudo mkswap /swap/swapfile
sudo swapon /swap/swapfile
echo '/swap/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab

# 配置网络参数
echo 'net.core.rmem_max=600000000' | sudo tee -a /etc/sysctl.conf
echo 'net.core.wmem_max=600000000' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

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

# 下载 cereumonyclient 仓库
cd /quilibrium
git clone https://github.com/QuilibriumNetwork/ceremonyclient.git

# 结束脚本
echo "Script completed successfully."

# 重启系统
sudo reboot

