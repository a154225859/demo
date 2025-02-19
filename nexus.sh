#!/bin/bash

# 定义文本格式
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
PINK='\033[1;35m'
PROVER_ID=""
FILE="/root/.nexus/node-id"
SERVICE_FILE="/etc/systemd/system/nexus.service"

# 自定义状态显示函数
show_status() {
    local message="$1"
    local status="$2"
    case $status in
        "error")
            echo -e "${RED}${BOLD}🚫 出错: ${message}${NORMAL}"
            ;;
        "progress")
            echo -e "${YELLOW}${BOLD}🔄 进行中: ${message}${NORMAL}"
            ;;
        "success")
            echo -e "${GREEN}${BOLD}🎉 成功: ${message}${NORMAL}"
            ;;
        *)
            echo -e "${PINK}${BOLD}${message}${NORMAL}"
            ;;
    esac
}

# 使用循环解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --prover-id)
      PROVER_ID="$2"
      shift # 跳过选项
      shift # 跳过选项值
      ;;
    *)
      exit 1
      ;;
  esac
done

# 如果提供了 PROVER_ID，先导入 ID
if [ -n "$PROVER_ID" ]; then
  # 创建目录（如果不存在）
  mkdir -p "$(dirname "$FILE")"
  # 写入内容
  echo "$PROVER_ID" > "$FILE"
  
  echo "已导入id: $PROVER_ID"
fi

# 安装 Rust
show_status "正在安装 Rust..." "progress"
if ! curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; then
    show_status "安装 Rust 失败。" "error"
    exit 1
fi

# 加载 Rust 环境
source /root/.cargo/env

# 更新软件包列表
show_status "更新软件包列表..." "progress"
if ! sudo apt update; then
    show_status "更新软件包列表失败。" "error"
    exit 1
fi

# 检查并安装 Git
if ! command -v git &> /dev/null; then
    show_status "Git 未安装。正在安装 Git..." "progress"
    if ! sudo apt install git -y; then
        show_status "安装 Git 失败。" "error"
        exit 1
    fi
else
    show_status "Git 已安装。" "success"
fi

# 删除已有的仓库（如果存在）
sudo systemctl stop nexus.service

if [ -d "/root/network-api" ]; then
    show_status "正在删除现有的仓库..." "progress"
    rm -rf "/root/network-api"
fi

# 克隆 Nexus-XYZ 网络 API 仓库
show_status "正在克隆 Nexus-XYZ 网络 API 仓库..." "progress"
if ! git clone https://github.com/nexus-xyz/network-api.git "/root/network-api"; then
    show_status "克隆仓库失败。" "error"
    exit 1
fi

cd /root/network-api
git -c advice.detachedHead=false checkout "$(git rev-list --tags --max-count=1)"

# 安装依赖项
cd /root/network-api/clients/cli
show_status "安装所需的依赖项..." "progress"
if ! sudo apt install protobuf-compiler build-essential pkg-config libssl-dev git-all -y; then
    show_status "安装依赖项失败。" "error"
    exit 1
fi

# 停止并禁用已有的 Nexus 服务（如果正在运行）
if systemctl is-active --quiet nexus.service; then
    show_status "nexus.service 当前正在运行。正在停止并禁用它..." "progress"
    sudo systemctl stop nexus.service
    sudo systemctl disable nexus.service
else
    show_status "nexus.service 未在运行。" "success"
fi

# 创建 systemd 服务文件
show_status "创建 systemd 服务..." "progress"
if ! sudo bash -c "cat > $SERVICE_FILE <<EOF
[Unit]
Description=Nexus XYZ Prover Service
After=network.target

[Service]
WorkingDirectory=/root/network-api/clients/cli
Environment=NONINTERACTIVE=1
ExecStart=/bin/bash -c 'yes | /root/.cargo/bin/cargo run --release -- --start --beta'
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF"; then
    show_status "创建 systemd 服务文件失败。" "error"
    exit 1
fi

# 重新加载 systemd 并启动服务
show_status "重新加载 systemd 并启动服务..." "progress"
if ! sudo systemctl daemon-reload; then
    show_status "重新加载 systemd 失败。" "error"
    exit 1
fi

if ! sudo systemctl start nexus.service; then
    show_status "启动服务失败。" "error"
    exit 1
fi

if ! sudo systemctl enable nexus.service; then
    show_status "启用服务失败。" "error"
    exit 1
fi

# 改进的服务状态检查逻辑
show_status "服务状态：" "progress"
if sudo systemctl is-active --quiet nexus.service; then
    show_status "服务正在运行。" "success"
else
    show_status "获取服务状态失败。" "error"
fi

show_status "Nexus Prover 安装和服务设置完成！" "success"

journalctl -u nexus.service -f -n 100
