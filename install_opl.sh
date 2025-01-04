#!/bin/bash
# 检查是否提供了参数
if [ -z "$1" ]; then
  echo "错误：没有提供参数，请提供 JSON 参数。"
  exit 1
fi

# 存储 JSON 参数
json_param="$1"
# 打印收到的 JSON 参数
echo "收到的 JSON 参数：$json_param"

sudo apt update -y

if ! command -v docker &> /dev/null; then
  echo "Docker not found. Installing Docker..."
  # 添加 Docker 官方 GPG 密钥
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
		
  # 设置 Docker 稳定版的 APT 源
  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
		
  # 安装必要的依赖包
  sudo apt-get install apt-transport-https ca-certificates gnupg lsb-release docker-ce docker-ce-cli containerd.io -y
		
  # 安装 Docker Compose
  sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d')/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

  sudo chmod +x /usr/local/bin/docker-compose
  sudo usermod -aG docker $USER
  newgrp docker
  echo "Docker installation complete."
else
  echo "Docker is already installed. "
fi

# 克隆 opl 仓库
echo "正在从 GitHub 克隆 opl 仓库..."
git clone https://github.com/a154225859/opl.git

# 创建 ./opl/keystore 目录
echo "创建 ./opl/keystore 目录..."
mkdir -p ./opl/keystore

# 将 JSON 参数写入到 ./opl/keystore/keystore.json 文件
echo "正在将 JSON 参数写入到 ./opl/keystore/keystore.json..."
echo "$json_param" > ./opl/keystore/keystore.json

# 进入 opl 目录
cd opl

# 以 detached 模式启动 docker-compose
echo "正在启动 docker-compose..."
docker-compose up -d
