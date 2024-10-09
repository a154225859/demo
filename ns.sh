#!/bin/bash

# 定义文本格式
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
PINK='\033[1;35m'

# 状态显示函数
show_status() {
    local message="$1"
    local status="$2"
    case $status in
        "error") echo -e "${RED}${BOLD}🚫 出错: ${message}${NORMAL}"; exit 1 ;;
        "progress") echo -e "${YELLOW}${BOLD}🔄 进行中: ${message}${NORMAL}" ;;
        "success") echo -e "${GREEN}${BOLD}🎉 成功: ${message}${NORMAL}" ;;
        *) echo -e "${PINK}${BOLD}${message}${NORMAL}" ;;
    esac
}

# 检查并安装所需软件包
install_if_missing() {
    local package="$1"
    if ! command -v $package &> /dev/null; then
        show_status "$package 未安装，正在安装..." "progress"
        if ! sudo apt install $package -y; then
            show_status "安装 $package 失败。" "error"
        fi
    else
        show_status "$package 已安装。" "success"
    fi
}

# 定义服务名称和文件路径
SERVICE_NAME="nexus"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

# 安装 Rust
show_status "正在安装 Rust..." "progress"
if ! curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; then
    show_status "安装 Rust 失败。" "error"
fi
source $HOME/.cargo/env

# 更新软件包列表
show_status "更新软件包列表..." "progress"
sudo apt update || show_status "更新软件包列表失败。" "error"

# 检查并安装 Git
install_if_missing "git"

# 删除已有的仓库（如果存在）
[ -d "$HOME/network-api" ] && show_status "删除现有的仓库..." "progress" && rm -rf "$HOME/network-api"

# 克隆 Nexus-XYZ 网络 API 仓库
show_status "正在克隆 Nexus-XYZ 网络 API 仓库..." "progress"
git clone https://github.com/nexus-xyz/network-api.git "$HOME/network-api" || show_status "克隆仓库失败。" "error"

# 安装依赖项
show_status "安装所需的依赖项..." "progress"
sudo apt install pkg-config libssl-dev -y || show_status "安装依赖项失败。" "error"

# 停止并禁用已有的 Nexus 服务（如果正在运行）
if systemctl is-active --quiet $SERVICE_NAME.service; then
    show_status "$SERVICE_NAME.service 当前正在运行，正在停止..." "progress"
    sudo systemctl stop $SERVICE_NAME.service
    sudo systemctl disable $SERVICE_NAME.service
else
    show_status "$SERVICE_NAME.service 未在运行。" "success"
fi

# 创建 systemd 服务文件
show_status "创建 systemd 服务..." "progress"
sudo bash -c "cat > $SERVICE_FILE <<EOF
[Unit]
Description=Nexus XYZ Prover Service
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/network-api/clients/cli
Environment=NONINTERACTIVE=1
ExecStart=$HOME/.cargo/bin/cargo run --release --bin prover -- beta.orchestrator.nexus.xyz
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF" || show_status "创建 systemd 服务文件失败。" "error"

# 重新加载 systemd 并启动服务
show_status "重新加载 systemd 并启动服务..." "progress"
sudo systemctl daemon-reload || show_status "重新加载 systemd 失败。" "error"
sudo systemctl start $SERVICE_NAME.service || show_status "启动服务失败。" "error"
sudo systemctl enable $SERVICE_NAME.service || show_status "启用服务失败。" "error"

# 服务状态检查
show_status "服务状态：" "progress"
if systemctl is-active --quiet $SERVICE_NAME.service; then
    show_status "$SERVICE_NAME.service 正在运行。" "success"
else
    show_status "$SERVICE_NAME.service 未在运行。" "error"
fi

show_status "Nexus Prover 安装和服务设置完成！" "success"
