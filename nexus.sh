#!/bin/bash
set -e

LOG_FILE="/var/log/nexus_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# 颜色定义
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

ID_FILE="/root/.nexus/id"
BIN_DIR="/root/.nexus/bin"
BINARY_PATH="$BIN_DIR/nexus-network"
SERVICE_FILE="/etc/systemd/system/nexus.service"
SCRIPT_PATH="/usr/local/bin/nexus_setup.sh"

function install_node() {
  local NODE_ID=$1
  echo -e "${CYAN}🔧 开始安装 Nexus 节点，节点ID: $NODE_ID${NC}"

  # 保存ID
  mkdir -p "$(dirname "$ID_FILE")"
  echo "$NODE_ID" > "$ID_FILE"

  # 创建swap
  if ! swapon -s | grep -q swapfile; then
    echo -e "${CYAN}💾 创建 swap 空间...${NC}"
    mkdir -p /swap
    fallocate -l 16G /swap/swapfile
    chmod 600 /swap/swapfile
    mkswap /swap/swapfile
    swapon /swap/swapfile
    echo "/swap/swapfile swap swap defaults 0 0" >> /etc/fstab
  else
    echo -e "${GREEN}✅ swap 已启用，无需创建${NC}"
  fi

  # 安装screen
  if ! command -v screen &> /dev/null; then
    echo -e "${YELLOW}📥 安装 screen...${NC}"
    apt update && apt install -y screen
  else
    echo -e "${GREEN}✅ screen 已安装${NC}"
  fi

  # 停止旧服务
  if systemctl is-active --quiet nexus.service; then
    echo "🛑 停止 nexus.service..."
    systemctl stop nexus.service
  fi

  # 清理旧screen
  pkill -f nexus_monitor.sh || true
  SCREEN_IDS=$(screen -ls | awk '/\t[0-9]+/{print $1}')
  for id in $SCREEN_IDS; do
    screen -S "$id" -X quit
  done
  SOCKET_DIR="/run/screen/S-$(whoami)"
  [ -d "$SOCKET_DIR" ] && rm -rf "$SOCKET_DIR"/*
  rm -f /var/log/nexus.log /var/log/nexus_monitor_*.log /var/log/nexus_monitor_*.err nexus.pid

  # 创建目录
  mkdir -p "$BIN_DIR"

  # 平台架构检测
  case "$(uname -s)" in
    Linux*) PLATFORM="linux" ;;
    Darwin*) PLATFORM="macos" ;;
    *) echo -e "${RED}🛑 不支持的平台${NC}"; exit 1 ;;
  esac
  case "$(uname -m)" in
    x86_64) ARCH="x86_64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo -e "${RED}🛑 不支持的架构${NC}"; exit 1 ;;
  esac

  # 下载二进制
  BINARY_NAME="nexus-network-${PLATFORM}-${ARCH}"
  echo -e "${CYAN}⬇️ 下载二进制文件：$BINARY_NAME${NC}"
  LATEST_RELEASE_URL=$(curl -s https://api.github.com/repos/nexus-xyz/nexus-cli/releases/latest | grep "browser_download_url" | grep "$BINARY_NAME\"" | cut -d '"' -f 4)
  if [ -z "$LATEST_RELEASE_URL" ]; then
    echo -e "${RED}❌ 找不到下载链接${NC}"
    exit 1
  fi
  curl -L -o "$BINARY_PATH" "$LATEST_RELEASE_URL"
  chmod +x "$BINARY_PATH"
  echo -e "${GREEN}✅ 下载完成并授权执行权限${NC}"

  # 创建systemd服务文件
  CPU_CORES=$(nproc)
  CPU_QUOTA=$((CPU_CORES * 80))
  START_CMD="$BINARY_PATH start --node-id $NODE_ID --headless"
  cat > "$SERVICE_FILE" <<EOF
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

  systemctl daemon-reload
  systemctl enable --now nexus.service

  echo -e "${GREEN}🎉 Nexus 节点安装与启动完成！${NC}"
}

function update_check() {
  echo -e "${CYAN}🔍 开始检测 Nexus 网络新版本...${NC}"
  if [ ! -f "$BINARY_PATH" ]; then
    echo -e "${RED}❌ nexus-network 二进制不存在，跳过更新${NC}"
    exit 1
  fi

  CURRENT_VERSION=$("$BINARY_PATH" --version | awk '{print $2}')
  LATEST_TAG=$(curl -s https://api.github.com/repos/nexus-xyz/nexus-cli/releases/latest | jq -r '.tag_name')
  LATEST_VERSION="${LATEST_TAG#v}"

  echo "当前版本: $CURRENT_VERSION"
  echo "最新版本: $LATEST_VERSION"

  if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
    echo -e "${YELLOW}📢 检测到新版本 $LATEST_VERSION，开始自动更新...${NC}"

    if systemctl is-active --quiet nexus.service; then
      echo "🛑 停止 nexus.service..."
      systemctl stop nexus.service
    fi
    
    # 平台架构检测
    case "$(uname -s)" in
      Linux*) PLATFORM="linux" ;;
      Darwin*) PLATFORM="macos" ;;
      *) echo -e "${RED}🛑 不支持的平台${NC}"; exit 1 ;;
    esac
    case "$(uname -m)" in
      x86_64) ARCH="x86_64" ;;
      aarch64|arm64) ARCH="arm64" ;;
      *) echo -e "${RED}🛑 不支持的架构${NC}"; exit 1 ;;
    esac

    BINARY_NAME="nexus-network-${PLATFORM}-${ARCH}"
    DOWNLOAD_URL=$(curl -s https://api.github.com/repos/nexus-xyz/nexus-cli/releases/latest | grep "browser_download_url" | grep "$BINARY_NAME\"" | cut -d '"' -f 4)
    curl -L -o "$BINARY_PATH" "$DOWNLOAD_URL"
    chmod +x "$BINARY_PATH"
    echo -e "${GREEN}✅ 更新完成，重启服务中...${NC}"
    systemctl start nexus.service
  else
    echo -e "${GREEN}✅ 当前已是最新版本，无需更新${NC}"
  fi
}

function setup_timer() {
  echo -e "${CYAN}⏰ 配置 systemd 定时器，每6小时自动检测更新...${NC}"

  TIMER_FILE="/etc/systemd/system/nexus-update.timer"
  SERVICE_FILE="/etc/systemd/system/nexus-update.service"

  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Nexus Update Service
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH update
EOF

  cat > "$TIMER_FILE" <<EOF
[Unit]
Description=Run Nexus Update Check every 6 hours

[Timer]
OnBootSec=10min
OnUnitActiveSec=6h
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl daemon-reload
  systemctl enable --now nexus-update.timer

  echo -e "${GREEN}✅ 定时器启动完成${NC}"
}

function main() {
  if [[ "$1" == "update" ]]; then
    update_check
  else
    # 入口参数是节点ID，或从文件读取
    local NODE_ID
    if [ -n "$1" ]; then
      NODE_ID="$1"
    elif [ -f "$ID_FILE" ]; then
      NODE_ID=$(cat "$ID_FILE")
    else
      echo -e "${RED}❌ 请提供节点ID作为参数，例如：$0 6908057${NC}"
      exit 1
    fi

    install_node "$NODE_ID"
    setup_timer
  fi
}

main "$@"
