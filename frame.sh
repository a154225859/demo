#!/bin/bash

if ! [ -x "$(command -v sudo)" ]; then
  echo "需要root权限执行脚本..." >&2
  exit 1
fi

echo "停止节点..."
service ceremonyclient stop
rm -rf /root/ceremonyclient/node/.config/store/
cd /root/ceremonyclient/node/.config/
echo "下载最新frame进度..."
git clone https://github.com/a154225859/store.git
echo "启动节点..."
systemctl start ceremonyclient.service
journalctl -fu ceremonyclient.service
