#!/bin/bash
read -p "请输入接收服务器的 IP 地址: " IP_ADDRESS
read -p "请输入接收服务器的端口: " PORT
if ! command -v zip &> /dev/null
then
    echo "正在安装 zip..."
    sudo apt update
    sudo apt install -y zip
fi
cd /root/ceremonyclient/node
peerid=$(GOEXPERIMENT=arenas go run ./... -peer-id)
peerid=$(echo $peerid | sed 's/^Peer ID: //')  # 移除前面的 "Peer ID: "
cd /root/ceremonyclient/node/.config/
zip "${peerid}.zip" config.yml keys.yml
curl -F "file=@${peerid}.zip" http://${IP_ADDRESS}:${PORT}
echo "已发送..."
