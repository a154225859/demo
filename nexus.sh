#!/bin/bash
set -e

# 日志输出到文件 & 控制台
LOG_FILE="/var/log/nexus_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# ANSI 色彩
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

NODE_ID="$1"
if [ -z "$NODE_ID" ]; then
  echo -e "${RED}❌ 请提供节点ID作为参数，例如：$0 6908057${NC}"
  exit 1
fi

echo -e "${CYAN}🔧 开始安装 Nexus 节点，节点ID: $NODE_ID${NC}"
echo "-------------------------------------------"

### 1. 创建 swap ###
if ! [ "$(sudo swapon -s)" ]; then
  echo -e "${CYAN}💾 创建 swap 空间...${NC}"
  sudo mkdir -p /swap
  sudo fallocate -l 16G /swap/swapfile
  sudo chmod 600 /swap/swapfile || { echo -e "${RED}❌ 设置 swap 权限失败${NC}"; exit 1; }
  sudo mkswap /swap/swapfile
  sudo swapon /swap/swapfile || { echo -e "${RED}❌ 启用 swap 失败${NC}"; exit 1; }
  echo "/swap/swapfile swap swap defaults 0 0" | sudo tee -a /etc/fstab
else
  echo -e "${GREEN}✅ swap 已启用，无需创建${NC}"
fi

### 2. 安装 screen ###
if ! command -v screen &> /dev/null; then
  echo -e "${YELLOW}📥 安装 screen...${NC}"
  sudo apt update && sudo apt install -y screen
else
  echo -e "${GREEN}✅ screen 已安装${NC}"
fi

### 3. 清理旧任务 ###
echo -e "${CYAN}🧹 清理 nexus_monitor 与旧 screen 会话...${NC}"
pkill -f nexus_monitor.sh || true

SCREEN_IDS=$(screen -ls | awk '/\t[0-9]+/{print $1}')
for id in $SCREEN_IDS; do
  echo -e "${YELLOW}⛔ 关闭 screen 会话：$id${NC}"
  screen -S "$id" -X quit
done

SOCKET_DIR="/run/screen/S-$(whoami)"
[ -d "$SOCKET_DIR" ] && sudo rm -rf "$SOCKET_DIR"/* && echo -e "${GREEN}✅ Socket 清理完成${NC}"

rm -f /var/log/nexus.log /var/log/nexus_monitor_*.log /var/log/nexus_monitor_*.err nexus.pid
echo -e "${GREEN}✅ 日志清理完成${NC}"

### 4. 设置安装路径 ###
NEXUS_HOME="/root/.nexus"
BIN_DIR="$NEXUS_HOME/bin"
mkdir -p "$BIN_DIR"
BINARY_PATH="$BIN_DIR/nexus-network"
START_CMD="$BINARY_PATH start --node-id $NODE_ID --headless"

### 5. 获取平台架构 ###
echo -e "${CYAN}🧠 检测平台架构...${NC}"
case "$(uname -s)" in
  Linux*) PLATFORM="linux" ;;
  Darwin*) PLATFORM="macos" ;;
  *) echo -e "${RED}🛑 不支持的系统平台${NC}"; exit 1 ;;
esac

case "$(uname -m)" in
  x86_64) ARCH="x86_64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo -e "${RED}🛑 不支持的系统架构${NC}"; exit 1 ;;
esac

### 6. 下载二进制文件 ###
BINARY_NAME="nexus-network-${PLATFORM}-${ARCH}"
echo -e "${CYAN}⬇️ 获取 Nexus 可执行文件（$BINARY_NAME）...${NC}"
LATEST_RELEASE_URL=$(curl -s https://api.github.com/repos/nexus-xyz/nexus-cli/releases/latest |
  grep "browser_download_url" | grep "$BINARY_NAME\"" | cut -d '"' -f 4)

if [ -z "$LATEST_RELEASE_URL" ]; then
  echo -e "${RED}❌ 未找到下载链接${NC}"
  exit 1
fi

curl -L -o "$BINARY_PATH" "$LATEST_RELEASE_URL"
chmod +x "$BINARY_PATH"
echo -e "${GREEN}✅ 下载完成并已授权执行权限${NC}"

### 7. 配置 systemd ###
echo -e "${CYAN}⚙️ 配置 systemd 服务...${NC}"
CPU_CORES=$(nproc)
CPU_QUOTA=$((CPU_CORES * 80))

cat > /lib/systemd/system/nexus.service <<EOF
[Unit]
Description=Nexus Network Node
After=network.target

[Service]
CPUQuota=${CPU_QUOTA}%
ExecStart=$START_CMD
Type=simple
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now nexus.service

### 8. 检查状态 ###
sleep 2
echo -e "${CYAN}🔍 Nexus 节点状态:${NC}"
systemctl status nexus.service --no-pager || true

echo -e "${GREEN}🎉 Nexus 节点安装与启动完成！日志见：journalctl -u nexus.service -f -n 100"
