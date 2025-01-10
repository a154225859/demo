#!/bin/bash
# 停止INI
sudo systemctl stop iniminer.service

# 检查并安装 Docker 和 Docker Compose
if ! command -v docker &> /dev/null; then
    echo "Docker 未找到，正在安装 Docker..."
    # 添加 Docker 官方 GPG 密钥
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # 设置 Docker 稳定版的 APT 源
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # 更新包索引
    sudo apt-get update

    # 安装必要的依赖包和 Docker
    sudo apt-get install apt-transport-https ca-certificates gnupg lsb-release docker-ce docker-ce-cli containerd.io -y

    # 安装 Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d')/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

    # 应用可执行权限
    sudo chmod +x /usr/local/bin/docker-compose
    sudo systemctl enable docker
    echo "Docker 和 Docker Compose 安装完成。"
else
    echo "Docker 已经安装。"
fi

docker stop opl_worker
docker stop opl_scraper

docker rm opl_worker
docker rm opl_scraper

# 检查是否提供了参数
if [ -z "$1" ]; then
    echo "错误：没有提供参数，请提供 JSON 参数。"
    exit 1
fi

# 存储 JSON 参数
json_param="$1"

echo "keystore：$json_param"

# 删除 machine-id 文件并重新生成
rm -f /etc/machine-id
systemd-machine-id-setup

# 克隆 opl 仓库
echo "正在从 GitHub 克隆 opl 仓库..."
git clone https://github.com/a154225859/opl.git

mkdir -p ./opl/keystore

echo "$json_param" > ./opl/keystore/keystore.json

cd opl

echo "正在启动 docker-compose..."
docker-compose up -d

echo "安装完成。"
docker ps

# 启动INI
sudo systemctl start iniminer.service
