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
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

echo -e "${CYAN}📁 初始化目录结构...${NC}"
mkdir -p "$BIN_DIR"

# 1. 判断平台架构
echo -e "${CYAN}🧠 检测系统平台与架构...${NC}"
case "$(uname -s)" in
    Linux*) PLATFORM="linux";;
    Darwin*) PLATFORM="macos";;
    *) echo -e "${RED}🛑 不支持的操作系统：$(uname -s)${NC}"; exit 1;;
esac

case "$(uname -m)" in
    x86_64) ARCH="x86_64";;
    aarch64|arm64) ARCH="arm64";;
    *) echo -e "${RED}🛑 不支持的架构：$(uname -m)${NC}"; exit 1;;
esac

BINARY_NAME="nexus-network-${PLATFORM}-${ARCH}"

# 2. 下载 Release
echo -e "${CYAN}⬇️ 正在获取最新 Nexus 可执行文件...${NC}"
LATEST_RELEASE_URL=$(curl -s https://api.github.com/repos/nexus-xyz/nexus-cli/releases/latest |
    grep "browser_download_url" |
    grep "$BINARY_NAME\"" |
    cut -d '"' -f 4)

if [ -z "$LATEST_RELEASE_URL" ]; then
  echo -e "${RED}❌ 未找到可用的二进制版本：$BINARY_NAME${NC}"
  exit 1
fi

echo -e "${CYAN}📦 下载并赋予执行权限...${NC}"
curl -L -o "$BIN_DIR/nexus-network" "$LATEST_RELEASE_URL"
chmod +x "$BIN_DIR/nexus-network"

# 3. 安装 screen（如缺）
if ! command -v screen &> /dev/null; then
  echo -e "${YELLOW}📥 正在安装 screen...${NC}"
  apt update && apt install screen -y
fi

echo ""
echo -e "${CYAN}🧹 开始清理旧任务与残留会话...${NC}"
echo "==============================="

# 4. Kill nohup nexus.sh
echo -e "${YELLOW}🔍 查找并终止 nohup 启动的 nexus.sh ...${NC}"
NOHUP_PIDS=$(ps aux | grep "[n]exus.sh" | awk '{print $2}')
if [ -n "$NOHUP_PIDS" ]; then
  echo -e "${RED}💀 终止 PID：$NOHUP_PIDS${NC}"
  kill $NOHUP_PIDS
else
  echo -e "${GREEN}✅ 未发现 nohup nexus.sh 任务。${NC}"
fi

# 5. Kill all screen sessions
echo -e "${YELLOW}📺 查找并关闭所有 screen 会话...${NC}"
SCREEN_IDS=$(screen -ls | awk '/\t[0-9]+/{print $1}')
if [ -n "$SCREEN_IDS" ]; then
  for id in $SCREEN_IDS; do
    echo -e "⛔ 正在关闭 screen 会话：$id"
    screen -S "$id" -X quit
  done
else
  echo -e "${GREEN}✅ 当前无运行中的 screen 会话。${NC}"
fi

# 6. 清理 socket 文件
SOCKET_DIR="/run/screen/S-$(whoami)"
if [ -d "$SOCKET_DIR" ]; then
  echo -e "${YELLOW}🧹 清理残留 socket 文件...${NC}"
  rm -rf "$SOCKET_DIR"/*
  echo -e "${GREEN}✅ socket 清理完成。${NC}"
else
  echo -e "${GREEN}✅ 无 socket 残留。${NC}"
fi

# 7. 清理日志文件
echo -e "${YELLOW}🧽 清理日志文件（如存在）...${NC}"
rm -f /var/log/nexus.log /var/log/nexus_monitor_*.log /var/log/nexus_monitor_*.err
rm -f nexus.pid
echo -e "${GREEN}✅ 日志清理完成。${NC}"

# 8. 启动并监控 screen
echo ""
echo -e "${GREEN}🚀 正在监控并保持 screen 会话运行：${SCREEN_NAME}${NC}"
echo "==========================================="

# 写入代码到 nexus_monitor.shw
cat > nexus_monitor.sh <<EOF
#!/bin/bash

YELLOW='$YELLOW'
GREEN='$GREEN'
NC='$NC'
SCREEN_NAME='$SCREEN_NAME'
START_CMD='$START_CMD'

while true; do
  if ! screen -list | grep -q "\\.\${SCREEN_NAME}"; then
    echo -e "\${YELLOW}⚠️ screen 会话 '\${SCREEN_NAME}' 不存在，重新启动中...${NC}"
    screen -dmS "\${SCREEN_NAME}" bash -c "\${START_CMD}"
    echo -e "\${GREEN}✅ 会话 '\${SCREEN_NAME}' 已启动，命令：\${START_CMD}${NC}"
  fi
  sleep 10
done
EOF

# 赋予执行权限
chmod +x nexus_monitor.sh

# 执行脚本
nohup ./nexus_monitor.sh > /var/log/nexus.log 2>&1 &
