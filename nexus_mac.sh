#!/bin/bash
set -e

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

NEXUS_IMAGE_NAME="nexus-node:latest"
NEXUS_LOG_DIR="$HOME/nexus_logs"
PLIST_NAME="com.nexus.logcleaner"
PLIST_FILE="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

mkdir -p "$NEXUS_LOG_DIR"

# 检查 Docker
if ! command -v docker &>/dev/null; then
  echo -e "${YELLOW}❌ Docker 未安装，请先安装 Docker Desktop：https://www.docker.com/products/docker-desktop${NC}"
  exit 1
fi

# 生成 Dockerfile 和 entrypoint.sh
echo -e "${GREEN}🔨 生成 Dockerfile 和 entrypoint.sh...${NC}"

cat > Dockerfile <<EOF
FROM ubuntu:20.04
RUN apt update && apt install -y curl && mkdir -p /app/logs
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh
ENTRYPOINT ["/app/entrypoint.sh"]
EOF

cat > entrypoint.sh <<'EOF'
#!/bin/bash
echo "📦 正在启动 Nexus 节点..."
mkdir -p /app/logs
while true; do
  echo "$(date) Nexus node running..." >> /app/logs/node.log
  sleep 60
done
EOF

# 构建镜像
docker build -t "$NEXUS_IMAGE_NAME" .
rm -f Dockerfile entrypoint.sh

echo -e "${GREEN}✅ 镜像构建完成：$NEXUS_IMAGE_NAME${NC}"

# 启动节点
run_node() {
  local NODE_ID="$1"
  if [[ -z "$NODE_ID" ]]; then
    echo "❌ 错误：需要传入节点 ID 作为参数，例如 run_node 1"
    return 1
  fi
  local NODE_ID_CLEAN=$(echo "$NODE_ID" | tr -cd 'a-zA-Z0-9_.-')
  local NODE_NAME="nexus-node-$NODE_ID_CLEAN"
  local LOG_FILE="$NEXUS_LOG_DIR/node_${NODE_ID_CLEAN}.log"

  # 确保宿主机日志文件存在，避免挂载目录
  if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
  fi

  echo -e "${GREEN}🚀 启动节点 $NODE_NAME...${NC}"
  docker run -d --name "$NODE_NAME" -v "$LOG_FILE":/app/logs/node.log "$NEXUS_IMAGE_NAME"
  echo -e "${GREEN}📄 日志保存于: $LOG_FILE${NC}"
}

# 停止卸载节点
uninstall_node() {
  local NODE_ID="$1"
  if [[ -z "$NODE_ID" ]]; then
    echo "❌ 错误：需要传入节点 ID 作为参数，例如 uninstall_node 1"
    return 1
  fi
  local NODE_ID_CLEAN=$(echo "$NODE_ID" | tr -cd 'a-zA-Z0-9_.-')
  local NODE_NAME="nexus-node-$NODE_ID_CLEAN"
  local LOG_FILE="$NEXUS_LOG_DIR/node_${NODE_ID_CLEAN}.log"

  echo -e "${YELLOW}🗑️ 正在停止并删除节点 $NODE_NAME...${NC}"
  docker stop "$NODE_NAME" && docker rm "$NODE_NAME"
  rm -f "$LOG_FILE"
}

# 查看日志
show_logs() {
  local NODE_ID="$1"
  if [[ -z "$NODE_ID" ]]; then
    echo "❌ 错误：需要传入节点 ID 作为参数，例如 show_logs 1"
    return 1
  fi
  local NODE_ID_CLEAN=$(echo "$NODE_ID" | tr -cd 'a-zA-Z0-9_.-')
  local LOG_FILE="$NEXUS_LOG_DIR/node_${NODE_ID_CLEAN}.log"

  echo -e "${GREEN}📜 查看节点 $NODE_ID 日志（Ctrl+C 退出）...${NC}"
  tail -f "$LOG_FILE"
}

# 列出运行节点
list_nodes() {
  echo -e "${GREEN}📊 当前运行的 Nexus 节点：${NC}"
  docker ps --filter "name=nexus-node-" --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}"
}

# 安装并启动 launchd 日志清理任务
setup_log_cleanup() {
  echo -e "${GREEN}🧹 配置 launchd 日志清理任务（每天0点删除前一天及更早日志）...${NC}"
  mkdir -p "$(dirname "$PLIST_FILE")"

  cat > "$PLIST_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$PLIST_NAME</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-c</string>
    <string>find "$NEXUS_LOG_DIR" -name "*.log" -mtime +0 -delete</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>0</integer>
    <key>Minute</key>
    <integer>0</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>$NEXUS_LOG_DIR/cleaner.out</string>
  <key>StandardErrorPath</key>
  <string>$NEXUS_LOG_DIR/cleaner.err</string>
</dict>
</plist>
EOF

  launchctl unload "$PLIST_FILE" 2>/dev/null || true
  launchctl load "$PLIST_FILE"

  echo -e "${GREEN}✅ 日志清理任务安装完成，每天0点自动清理日志。${NC}"
}

# 自动安装日志清理任务
setup_log_cleanup

# 提示信息
echo -e "${GREEN}🎉 初始设置完成！${NC}"
echo -e "你可以手动调用以下函数管理节点："
echo -e "  ${YELLOW}run_node NODE_ID${NC}    # 启动节点"
echo -e "  ${YELLOW}uninstall_node NODE_ID${NC}  # 停止并删除节点"
echo -e "  ${YELLOW}list_nodes${NC}          # 查看节点状态"
echo -e "  ${YELLOW}show_logs NODE_ID${NC}     # 查看节点日志"

