#!/bin/bash

# Function to start HTTP server on Ubuntu A
start_server() {
    # 提示用户输入端口
    read -p "请输入本机接收文件的端口: " PORT

    # 检查是否安装了 Python3
    if ! command -v python3 &> /dev/null
    then
        echo "正在安装 Python3..."
        sudo apt update
        sudo apt install -y python3
    fi

    # 启动 Python HTTP 服务器
    echo "正在 ${PORT} 上启动 Python HTTP 服务器..."
    python3 -m http.server ${PORT}
}

# Function to compress files and upload on Ubuntu B
upload_files() {
    # 提示用户输入IP地址和端口
    read -p "请输入接收服务器的 IP 地址: " IP_ADDRESS
    read -p "请输入接收服务器的端口: " PORT

    # 检查是否安装了 zip
    if ! command -v zip &> /dev/null
    then
        echo "正在安装 zip..."
        sudo apt update
        sudo apt install -y zip
    fi

    # 获取 peerid
    cd /root/ceremonyclient/node
    peerid=$(GOEXPERIMENT=arenas go run ./... -peer-id)

    # 压缩文件
    cd /root/ceremonyclient/node/.config/
    zip "${peerid}.zip" config.yml keys.yml

    # 上传文件
    curl -F "file=@${peerid}.zip" http://${IP_ADDRESS}:${PORT}
}

# Main script
echo "选择操作模式:"
echo "1. 接收其他机器的key"
echo "2. 将key上传到服务器"
read -p "请输入您的选择 (1 或 2): " choice

case $choice in
    1)
        start_server
        ;;
    2)
        upload_files
        ;;
    *)
        echo "无效选择。请输入 1 或 2。"
        ;;
esac
