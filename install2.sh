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

# 启用并启动服务
systemctl enable ceremonyclient.service

# 清理 Go 编译缓存
echo "Cleaning Go build cache..."
cd /root/ceremonyclient/node
GOEXPERIMENT=arenas go clean -v -n -a ./...

# 删除旧的可执行文件
echo "Removing old executable..."
rm /root/go/bin/node

# 重新安装
echo "Reinstalling the node..."
GOEXPERIMENT=arenas go install ./...

reboot
