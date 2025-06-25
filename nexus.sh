#!/bin/bash

set -e

NEXUS_HOME="/root/.nexus"
BIN_DIR="$NEXUS_HOME/bin"
NODE_ID="$1"
SERVICE_NAME="nexus-node-${NODE_ID}.service"
SCREEN_NAME="ns_${NODE_ID}"

GREEN='\033[1;32m'
ORANGE='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'  # No Color

if [ -z "$NODE_ID" ]; then
  echo -e "${RED}❌ 错误：请提供节点ID作为参数，例如：$0 6908057${NC}"
  exit 1
fi

# 确保目录存在
mkdir -p "$BIN_DIR"

# 判断平台和架构
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

# 获取下载链接
LATEST_RELEASE_URL=$(curl -s https://api.github.com/repos/nexus-xyz/nexus-cli/releases/latest |
    grep "browser_download_url" |
    grep "$BINARY_NAME\"" |
    cut -d '"' -f 4)

if [ -z "$LATEST_RELEASE_URL" ]; then
  echo -e "${RED}❌ 找不到 $BINARY_NAME 对应的 Release${NC}"
  exit 1
fi

echo "⬇️ 下载 Nexus 可执行文件..."
curl -L -o "$BIN_DIR/nexus-network" "$LATEST_RELEASE_URL"
chmod +x "$BIN_DIR/nexus-network"

# 安装 screen
if ! command -v screen >/dev/null 2>&1; then
  echo "📦 安装 screen..."
  apt update && apt install screen -y
fi

# 生成 systemd 服务文件
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"

echo "🛠️ 生成 systemd 服务：$SERVICE_FILE"
cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Nexus Node $NODE_ID Screen Wrapper
After=network.target

[Service]
Type=simple
ExecStartPre=/usr/bin/screen -S ${SCREEN_NAME} -X quit || true
ExecStart=/usr/bin/screen -DmS ${SCREEN_NAME} ${BIN_DIR}/nexus-network start --node-id ${NODE_ID}
ExecStop=/usr/bin/screen -S ${SCREEN_NAME} -X quit
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 并启动服务
echo "🔄 重新加载 systemd..."
systemctl daemon-reload

echo "🚀 启动并设置开机自启..."
systemctl enable --now "$SERVICE_NAME"

echo -e "${GREEN}✅ 节点 $NODE_ID 安装并运行成功！${NC}"
echo "🎯 查看日志："
echo "    screen -r $SCREEN_NAME"
echo "📊 检查状态："
echo "    systemctl status $SERVICE_NAME"
