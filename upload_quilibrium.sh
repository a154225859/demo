#!/bin/bash

# 提示用户输入上传 URL
read -p "请输入上传 URL: " upload_url

exec_start=$(sed -n 's/^ExecStart=\/root\/ceremonyclient\/node\///p' /lib/systemd/system/ceremonyclient.service)
# 进入工作目录
cd /root/ceremonyclient/node

# 获取 peerid
peerid=$(./$exec_start -peer-id)
peerid=$(echo $peerid | grep -o 'Qm[[:alnum:]]\+')
echo "Peer ID: $peerid"

# 进入 .config 目录
cd /root/ceremonyclient/node/.config

# 删除现有的 peerid.zip 文件（如果存在）
rm -f "${peerid}.zip"

# 压缩 .config 目录中的所有文件到 peerid.zip
zip -r "${peerid}.zip" *

# 上传文件
file_path="/root/ceremonyclient/node/.config/${peerid}.zip"

# 使用 curl 上传文件并显示进度条
curl -F "file=@${file_path}" ${upload_url} --progress-bar

# 打印上传成功信息
echo "文件 ${peerid}.zip 已成功上传到 ${upload_url}"
