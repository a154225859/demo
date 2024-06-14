#!/bin/bash

# 更新包索引
sudo apt-get update

# 安装必要的依赖包
sudo apt-get install apt-transport-https git wget tar curl zip ca-certificates curl gnupg lsb-release screen -y

if ! [ "$(sudo swapon -s)" ]; then
  echo "创建swap..."
  sudo mkdir /swap && sudo fallocate -l 24G /swap/swapfile && sudo chmod 600 /swap/swapfile || { echo "Failed to create swap space! Exiting..."; exit 1; }
  sudo mkswap /swap/swapfile && sudo swapon /swap/swapfile || { echo "Failed to set up swap space! Exiting..."; exit 1; }
  sudo bash -c 'echo "/swap/swapfile swap swap defaults 0 0" >> /etc/fstab' || { echo "Failed to update /etc/fstab! Exiting..."; exit 1; }
fi

echo "配置网络参数..."
if [[ $(grep ^"net.core.rmem_max=600000000"$ /etc/sysctl.conf) ]]; then
  echo "\net.core.rmem_max=600000000\" found inside /etc/sysctl.conf, skipping..."
else
  echo -e "\n# Change made to increase buffer sizes for better network performance for ceremonyclient\nnet.core.rmem_max=600000000" | sudo tee -a /etc/sysctl.conf > /dev/null
fi
if [[ $(grep ^"net.core.wmem_max=600000000"$ /etc/sysctl.conf) ]]; then
  echo "\net.core.wmem_max=600000000\" found inside /etc/sysctl.conf, skipping..."
else
  echo -e "\n# Change made to increase buffer sizes for better network performance for ceremonyclient\nnet.core.wmem_max=600000000" | sudo tee -a /etc/sysctl.conf > /dev/null
fi
sudo sysctl -p

# 添加 Docker 官方 GPG 密钥
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# 设置 Docker 稳定版的 APT 源
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 再次更新包索引
sudo apt-get update

# 安装 Docker Engine
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# 安装 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d')/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# 应用可执行权限
sudo chmod +x /usr/local/bin/docker-compose

# 创建目录
mkdir -p /home/citrea
mkdir -p /home/citrea/fulldate
mkdir -p /home/citrea/bitcoindate

# 下载 citrea.yml
cd /home/citrea && curl -o docker-compose.yml https://raw.githubusercontent.com/a154225859/demo/main/citrea.yml

启动 Docker Compose 服务
sudo docker-compose up -d
