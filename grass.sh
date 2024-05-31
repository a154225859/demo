#!/bin/bash

# 定义变量
SERVICE_FILE="/etc/systemd/system/grass.service"
SERVICE_NAME="grass.service"
SCRIPT_URL="https://raw.githubusercontent.com/a154225859/demo/main/grass.py"
SCRIPT_PATH="/root/grass.py"

# 启动服务
echo "Starting service $SERVICE_NAME..."
systemctl stop $SERVICE_NAME

# 下载 grass.py 文件
echo "Downloading grass.py..."
curl -o $SCRIPT_PATH $SCRIPT_URL

# 确保文件有执行权限
chmod +x $SCRIPT_PATH

# 安装 Python 依赖包
echo "Installing required Python packages..."
apt install python3-pip
pip3 install websockets loguru

# 创建服务文件内容
SERVICE_CONTENT="[Unit]
Description=Grass Python Script Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 $SCRIPT_PATH
WorkingDirectory=/root
StandardOutput=inherit
StandardError=inherit
Restart=always
User=root

[Install]
WantedBy=multi-user.target"

# 创建服务文件
echo "Creating service file at $SERVICE_FILE..."
echo "$SERVICE_CONTENT" > $SERVICE_FILE

# 重新加载 systemd 配置
echo "Reloading systemd daemon..."
systemctl daemon-reload

# 启用服务
echo "Enabling service $SERVICE_NAME..."
systemctl enable $SERVICE_NAME

cat <<EOF > /root/glog.sh
journalctl -fu grass.service
EOF
chmod +x /root/glog.sh

# 启动服务
echo "Starting service $SERVICE_NAME..."
systemctl start $SERVICE_NAME

# 检查服务状态
echo "Checking service status..."
journalctl -fu grass.service
