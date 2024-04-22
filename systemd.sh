#!/bin/bash

# 确保脚本以 root 权限运行
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# 创建系统服务文件
echo "Creating systemd service for Ceremony Client Go App..."

cat <<EOF > /lib/systemd/system/ceremonyclient.service
[Unit]
Description=Ceremony Client Go App Service

[Service]
Type=simple
Restart=always
RestartSec=5s
WorkingDirectory=/root/ceremonyclient/node
Environment=GOEXPERIMENT=arenas
ExecStart=/root/go/bin/node ./..

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 以读取新的服务文件
systemctl daemon-reload

# 启用并启动服务
systemctl enable ceremonyclient.service
systemctl start ceremonyclient.service

echo "Ceremony Client service has been created and started."
