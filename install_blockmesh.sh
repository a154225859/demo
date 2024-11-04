#!/bin/bash

# 更新并升级系统软件包
apt update
apt upgrade -y

# 安装 Docker 和 Docker Compose
install_docker_and_compose() {
    echo "正在安装 Docker 和 Docker Compose..."
    curl -fsSL https://raw.githubusercontent.com/a154225859/demo/main/install_docker.sh | bash
}

# 检查并安装 Docker 和 Docker Compose
if ! command -v docker &> /dev/null || ! command -v docker-compose &> /dev/null; then
    install_docker_and_compose
else
    echo "Docker 和 Docker Compose 已安装，跳过安装步骤..."
fi
# 清理旧文件
rm -rf blockmesh-cli.tar.gz target

# 创建用于解压的目标目录
mkdir -p target/release

# 下载并解压最新版 BlockMesh CLI
echo "下载并解压 BlockMesh CLI..."
curl -L https://github.com/block-mesh/block-mesh-monorepo/releases/download/v0.0.327/blockmesh-cli-x86_64-unknown-linux-gnu.tar.gz -o blockmesh-cli.tar.gz
if tar -xzf blockmesh-cli.tar.gz --strip-components=3 -C target/release; then
    echo "解压成功"
else
    echo "解压失败，请检查下载链接或网络连接。退出..."
    exit 1
fi

# 验证解压结果
if [[ ! -f target/release/blockmesh-cli ]]; then
    echo "错误：未找到 blockmesh-cli 可执行文件于 target/release。退出..."
    exit 1
fi

# 提示输入邮箱和密码
read -p "请输入您的 BlockMesh 邮箱: " email
read -s -p "请输入您的 BlockMesh 密码: " password
echo

# 使用 BlockMesh CLI 创建后台运行的 Docker 容器
echo "为 BlockMesh CLI 创建 Docker 容器并后台运行..."
docker run -d \
    --name blockmesh-cli-container \
    -v "$(pwd)/target/release:/app" \
    -e EMAIL="$email" \
    -e PASSWORD="$password" \
    --workdir /app \
    ubuntu:22.04 ./blockmesh-cli --email "$email" --password "$password"
