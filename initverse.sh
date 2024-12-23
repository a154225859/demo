#!/bin/bash

# 检查是否传入了钱包地址和工作者名称
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "错误: 请提供钱包地址和工作者名称。"
  echo "用法: ./initverse.sh <YOUR_WALLET_ADDRESS> <WORKER_NAME>"
  exit 1
fi

WALLET_ADDRESS=$1
WORKER_NAME=$2

# 设置工作目录为 /root/iniminer
WORKING_DIR="/root/iniminer"

# 切换到指定的工作目录
echo "切换到工作目录 $WORKING_DIR ..."
mkdir $WORKING_DIR
cd $WORKING_DIR || { echo "错误: 无法切换到目录 $WORKING_DIR"; exit 1; }

# 下载 Iniminer
echo "正在下载 Iniminer..."
wget https://github.com/Project-InitVerse/ini-miner/releases/download/v1.0.0/iniminer-linux-x64

# 添加执行权限
echo "正在设置执行权限..."
chmod +x iniminer-linux-x64

# 创建 systemd 服务文件
echo "正在创建 systemd 服务文件..."
SERVICE_FILE="/etc/systemd/system/iniminer.service"

cat > $SERVICE_FILE << EOF
[Unit]
Description=Iniminer 挖矿服务
After=network.target

[Service]
ExecStart=$WORKING_DIR/iniminer-linux-x64 --pool stratum+tcp://$WALLET_ADDRESS.$WORKER_NAME@pool-core-testnet.inichain.com:32672
WorkingDirectory=$WORKING_DIR
User=root
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# 更新 systemd 配置
echo "正在重新加载 systemd 配置..."
systemctl daemon-reload

# 启动服务
echo "正在启动 Iniminer 服务..."
systemctl start iniminer.service

# 设置开机启动
echo "正在设置 Iniminer 服务开机启动..."
systemctl enable iniminer.service

# 查看服务状态
echo "正在检查 Iniminer 服务状态..."
journalctl -u iniminer.service -f -n 100
