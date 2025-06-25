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

echo "🔍 正在查找所有 screen 会话..."

# 5.获取所有 screen 会话 ID（Detached 或 Attached）
SCREEN_IDS=$(screen -ls | awk '/\t[0-9]+/{print $1}')

if [ -z "$SCREEN_IDS" ]; then
  echo "✅ 没有正在运行的 screen 会话。"
else
  echo "🧨 正在关闭以下 screen 会话："
  echo "$SCREEN_IDS"
  for id in $SCREEN_IDS; do
    screen -S "$id" -X quit
  done
  echo "✅ 所有 screen 会话已尝试关闭。"
fi

# 6.清理残留 socket
SOCKET_DIR="/run/screen/S-$(whoami)"
if [ -d "$SOCKET_DIR" ]; then
  echo "🧹 正在清理残留 socket 文件..."
  rm -rf "$SOCKET_DIR"/*
  echo "✅ socket 清理完成。"
else
  echo "🧼 无 socket 残留。"
fi

# 7. 启动并监控 screen 会话
echo -e "${GREEN}🚀 启动并监控 screen 会话: $SCREEN_NAME${NC}"

while true; do
  if ! screen -list | grep -q "\.${SCREEN_NAME}"; then
    echo "⚠️ screen 会话 '$SCREEN_NAME' 不存在，正在重新启动..."
    screen -dmS "$SCREEN_NAME" bash -c "$START_CMD"
    echo "✅ 会话 '$SCREEN_NAME' 已重启，执行：$START_CMD"
  fi
  sleep 10
done
