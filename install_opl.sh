#!/bin/bash

# 停止 INI 服务
systemctl stop iniminer.service

# 检查并安装 Docker 和 Docker Compose
if ! command -v docker &> /dev/null; then
    echo "Docker 未找到，正在安装 Docker..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install apt-transport-https ca-certificates gnupg lsb-release docker-ce docker-ce-cli containerd.io -y

    ARCH=$(uname -m)
    curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)/docker-compose-$(uname -s)-$ARCH" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo "Docker 和 Docker Compose 安装完成。"
else
    echo "Docker 已经安装。"
fi

docker stop opl_worker
docker stop opl_scraper

docker rm opl_worker
docker rm opl_scraper

# 检查参数
if [ -z "$1" ]; then
    echo "错误：没有提供参数，请提供 JSON 参数。"
    exit 1
fi

json_param="$1"

# 删除并重新生成 machine-id
rm -f /etc/machine-id
systemd-machine-id-setup

# 克隆仓库
echo "正在从 GitHub 克隆 opl 仓库..."
rm -rf opl
git clone https://github.com/a154225859/opl.git || { echo "克隆仓库失败！"; exit 1; }

# 写入 keystore
mkdir -p /root/opl/keystore
echo "$json_param" > /root/opl/keystore/keystore.json

# 创建 Systemd 服务文件
SERVICE_FILE="/etc/systemd/system/opl-docker.service"

bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=Docker Compose Service for OPL
Requires=docker.service
After=docker.service

[Service]
WorkingDirectory=/root/opl
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

echo "Systemd 服务文件已创建：$SERVICE_FILE"

# 启用并启动服务
systemctl daemon-reload
systemctl enable opl-docker.service
systemctl start opl-docker.service

# 启动 INI 服务
systemctl start iniminer.service

echo "安装完成，Docker Compose 已作为服务启动并设置为开机启动。"
