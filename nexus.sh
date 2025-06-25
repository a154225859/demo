#!/bin/bash

set -e

NODE_ID="$1"
if [ -z "$NODE_ID" ]; then
  echo "❌ 请提供节点ID作为参数，例如：$0 6908057"
  exit 1
fi

NEXUS_HOME="/root/.nexus"
BIN_DIR="$NEXUS_HOME/bin"
SCREEN_NAME="ns_${NODE_ID}"
START_CMD="$BIN_DIR/nexus-network start --node-id $NODE_ID"

# ANSI colors
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'

# 1. 确保目录存在
mkdir -p "$BIN_DIR"

# 2. 判断平台架构
case "$(uname -s)" in
    Linux*) PLATFORM="linux";;
    Darwin*) PLATFORM="macos";;
    *) echo "${RED}Unsupported OS$(uname -s)${NC}"; exit 1;;
esac

case "$(uname -m)" in
    x86_64) ARCH="x86_64";;
    aarch64|arm64) ARCH="arm64";;
    *) echo "${RED}Unsupported arch: $(uname -m)${NC}"; exit 1;;
esac

BINARY_NAME="nexus-network-${PLATFORM}-${ARCH}"

# 3. 下载最新 Release
LATEST_RELEASE_URL=$(curl -s https://api.github.com/repos/nexus-xyz/nexus-cli/releases/latest |
    grep "browser_download_url" |
    grep "$BINARY_NAME\"" |
    cut -d '"' -f 4)

if [ -z "$LATEST_RELEASE_URL" ]; then
  echo -e "${RED}❌ 未找到对应二进制文件${NC}"
  exit 1
fi

echo "⬇️ 下载 Nexus 节点二进制..."
curl -L -o "$BIN_DIR/nexus-network" "$LATEST_RELEASE_URL"
chmod +x "$BIN_DIR/nexus-network"

# 4. 安装 screen（如缺）
if ! command -v screen &> /dev/null; then
  echo "📦 安装 screen..."
  apt update && apt install screen -y
fi

# 5. 启动并监控 screen 会话
echo -e "${GREEN}🚀 启动并监控 screen 会话: $SCREEN_NAME${NC}"

while true; do
  if ! screen -list | grep -q "\.${SCREEN_NAME}"; then
    echo "⚠️ screen 会话 '$SCREEN_NAME' 不存在，正在重新启动..."
    screen -dmS "$SCREEN_NAME" bash -c "$START_CMD"
    echo "✅ 会话 '$SCREEN_NAME' 已重启，执行：$START_CMD"
  fi
  sleep 10
done
