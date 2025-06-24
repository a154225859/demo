#!/bin/bash

set -e

# -----------------------------------------------------------------------------
# 1. 参数校验
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
SCREEN_NAME="nexus"

mkdir -p "$BIN_DIR"

# -----------------------------------------------------------------------------
# 3. 下载 nexus-network 二进制
# -----------------------------------------------------------------------------
echo "🔽 正在下载 Nexus CLI..."

LATEST_RELEASE_URL=$(curl -s https://api.github.com/repos/nexus-xyz/nexus-cli/releases/latest |
  grep "browser_download_url" |
  grep "$BINARY_NAME\"" |
  cut -d '"' -f 4)

if [ -z "$LATEST_RELEASE_URL" ]; then
  echo "❌ 无法获取 Nexus CLI 下载地址"
  exit 1
fi

curl -L -f -o "$BINARY_PATH" "$LATEST_RELEASE_URL"
chmod +x "$BINARY_PATH"

# -----------------------------------------------------------------------------
# 4. 检查并安装 screen（如未安装）
# -----------------------------------------------------------------------------
if ! command -v screen >/dev/null 2>&1; then
  echo "📦 未检测到 screen，正在安装..."
  sudo apt update && sudo apt install screen -y
fi

# -----------------------------------------------------------------------------
# 5. 启动 screen 会话（如未已存在）
# -----------------------------------------------------------------------------
if screen -list | grep -q "\.${SCREEN_NAME}"; then
  echo "✅ Screen 会话 '$SCREEN_NAME' 已在运行。使用以下命令恢复："
  echo "    screen -r $SCREEN_NAME"
else
  echo "🚀 启动 Nexus 节点 screen 会话..."
  screen -dmS "$SCREEN_NAME" "$BINARY_PATH" start --node-id "$NODE_ID"
  echo "✅ 已启动！使用以下命令查看/进入会话："
  echo "    screen -r $SCREEN_NAME"
fi
