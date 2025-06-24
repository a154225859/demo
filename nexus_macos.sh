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

echo -e "${GREEN}🧪 检测 Docker 是否安装...${NC}"
if ! command -v docker &>/dev/null; then
  echo -e "${YELLOW}❌ Docker 未安装，请先安装 Docker Desktop：https://www.docker.com/products/docker-desktop${NC}"
  exit 1
fi

echo -e "${GREEN}🔨 构建 Nexus 镜像...${NC}"
cat > Dockerfile <<EOF
FROM ubuntu:20.04
RUN apt update && apt install -y curl && mkdir /app
COPY entrypoint.sh /app/entrypoint.sh
ENTRYPOINT ["/app/entrypoint.sh"]
EOF

cat > entrypoint.sh <<'EOF'
#!/bin/bash
echo "📦 启动 Nexus 节点..."
while true; do echo "$(date) Nexus node running..." >> /app/logs/node.log; sleep 60; done
EOF

chmod +x entrypoint.sh
docker build -t "$NEXUS_IMAGE_NAME" .
rm -f Dockerfile entrypoint.sh
echo -e "${GREEN}✅ 镜像构建完成: $NEXUS_IMAGE_NAME${NC}"

echo -e "${GREEN}🧹 配置 launchd 日志清理任务（每天0点删除前一天及更早日志）...${NC}"

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

echo -e "${GREEN}✅ 日志清理任务已安装并启动，每天0点执行。${NC}"

echo -e "${GREEN}🎉 初始设置完成！如需启动节点，请手动运行脚本中的函数，例如：${NC}"
echo -e "  ${YELLOW}run_node NODE_ID${NC}  # 启动节点"
echo -e "  ${YELLOW}uninstall_node NODE_ID${NC}  # 停止卸载节点"
echo -e "  ${YELLOW}list_nodes${NC}  # 查看节点状态"
echo -e "  ${YELLOW}show_logs NODE_ID${NC}  # 查看节点日志"

# 函数定义，供手动调用：

run_node() {
  local NODE_ID="$1"
  if [[ -z "$NODE_ID" ]]; then
    echo "❌ 错误：需要传入节点 ID 作为参数，例如 run_node 1"
    return 1
  fi

  # 过滤非法字符，保证容器名合法
  local NODE_ID_CLEAN
  NODE_ID_CLEAN=$(echo "$NODE_ID" | tr -cd 'a-zA-Z0-9_.-')
  local NODE_NAME="nexus-node-$NODE_ID_CLEAN"
  local LOG_FILE="$NEXUS_LOG_DIR/node_${NODE_ID_CLEAN}.log"

  echo -e "${GREEN}🚀 启动节点 $NODE_NAME...${NC}"

  docker run -d \
    --name "$NODE_NAME" \
    -v "$LOG_FILE":/app/logs/node.log \
    "$NEXUS_IMAGE_NAME"

  echo -e "${GREEN}📄 日志保存于: $LOG_FILE${NC}"
}

uninstall_node() {
  local NODE_ID=\$1
  local NODE_NAME="nexus-node-\$NODE_ID"
  local LOG_FILE="$NEXUS_LOG_DIR/node_\$NODE_ID.log"
  echo -e "${YELLOW}🗑️ 停止并删除 \$NODE_NAME...${NC}"
  docker stop "\$NODE_NAME" && docker rm "\$NODE_NAME"
  rm -f "\$LOG_FILE"
}

list_nodes() {
  echo -e "${GREEN}📊 当前运行的 Nexus 节点：${NC}"
  docker ps --filter "name=nexus-node-" --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}"
}

show_logs() {
  local NODE_ID=\$1
  local LOG_FILE="$NEXUS_LOG_DIR/node_\$NODE_ID.log"
  echo -e "${GREEN}📜 查看节点 \$NODE_ID 日志（Ctrl+C 退出）...${NC}"
  tail -f "\$LOG_FILE"
}
