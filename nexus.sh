#!/bin/sh

set -e

# -----------------------------------------------------------------------------
# 1. 参数：直接接受 node-id 作为第一个参数
# -----------------------------------------------------------------------------
NODE_ID="$1"

if [ -z "$NODE_ID" ]; then
  echo "用法: ./nexus.sh <your-node-id>"
  exit 1
fi

# -----------------------------------------------------------------------------
# 2. 基本路径设置
# -----------------------------------------------------------------------------
NEXUS_HOME="$HOME/.nexus"
BIN_DIR="$NEXUS_HOME/bin"
BINARY_NAME="nexus-network-linux-x86_64"
BINARY_PATH="$BIN_DIR/nexus-network"
SERVICE_NAME="nexus.service"

mkdir -p "$BIN_DIR"

# -----------------------------------------------------------------------------
# 3. 下载 nexus-network 二进制
# -----------------------------------------------------------------------------
echo "🔽 下载 Nexus CLI..."
LATEST_RELEASE_URL=$(curl -s https://api.github.com/repos/nexus-xyz/nexus-cli/releases/latest |
  grep "browser_download_url" |
  grep "$BINARY_NAME\"" |
  cut -d '"' -f 4)

curl -L -f -o "$BINARY_PATH" "$LATEST_RELEASE_URL"
chmod +x "$BINARY_PATH"

# -----------------------------------------------------------------------------
# 4. 创建 systemd 用户服务
# -----------------------------------------------------------------------------
SERVICE_FILE="$HOME/.config/systemd/user/$SERVICE_NAME"
mkdir -p "$(dirname "$SERVICE_FILE")"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Nexus Network Node
After=network.target

[Service]
ExecStart=$BINARY_PATH start --node-id $NODE_ID
Restart=always
RestartSec=5s

[Install]
WantedBy=default.target
EOF

# -----------------------------------------------------------------------------
# 5. 启动服务
# -----------------------------------------------------------------------------
echo "🚀 启动 Nexus systemd 服务..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME"

# -----------------------------------------------------------------------------
# 6. 提示完成
# -----------------------------------------------------------------------------
echo "✅ Nexus 启动成功！（服务名：nexus）"
journalctl -u nexus -f
