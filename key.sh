#!/bin/bash
sudo apt update
sudo apt install zip

# 提示用户输入IP地址和端口
read -p "Enter the IP address of the server: " IP_ADDRESS
read -p "Enter the port of the server: " PORT

# 获取 peerid
cd /root/ceremonyclient/node
peerid=$(GOEXPERIMENT=arenas go run ./... -peer-id)

# 压缩文件
cd /root/ceremonyclient/node/.config/
zip "${peerid}.zip" config.yml keys.yml

# 上传文件
curl -F "file=@${peerid}.zip" http://${IP_ADDRESS}:${PORT}
