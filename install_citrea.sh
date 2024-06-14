#!/bin/bash

# 更新包索引
sudo apt-get update

# 安装必要的依赖包
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

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
