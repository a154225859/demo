#!/bin/bash

# 检查系统架构
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
  URL="https://github.com/cloudreve/Cloudreve/releases/download/3.8.3/cloudreve_3.8.3_linux_amd64.tar.gz"
elif [[ "$ARCH" == "aarch64" ]]; then
  URL="https://github.com/cloudreve/Cloudreve/releases/download/3.8.3/cloudreve_3.8.3_linux_arm64.tar.gz"
else
  echo "不支持的架构: $ARCH"
  exit 1
fi

# 下载安装包
if wget -4 $URL; then
  echo "下载安装包成功..."
else
  echo "下载安装包失败..."
  exit 1
fi

# 提取包文件名
FILE_NAME=$(basename $URL)

# 检查是否存在cloudreve文件夹，如果不存在则创建
INSTALL_DIR="/home/cloudreve"
if [ ! -d "$INSTALL_DIR" ]; then
  sudo mkdir -p $INSTALL_DIR
  echo "创建文件夹 $INSTALL_DIR 成功..."
fi

# 解压安装包
if sudo tar -C $INSTALL_DIR -xzf $FILE_NAME; then
  echo "解压安装包成功..."
else
  echo "解压安装包失败..."
  exit 1
fi

# 删除安装包
sudo rm $FILE_NAME
echo "删除安装包成功..."

echo "Create/update the systemd service file for Cloudreve"
cat <<EOF > /lib/systemd/system/cloudreve.service
[Unit]
Description=Cloudreve Service

[Service]
Type=simple
Restart=always
RestartSec=5s
WorkingDirectory=/home/cloudreve
ExecStart=/home/cloudreve/cloudreve

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable cloudreve.service
echo "Start the cloudreve service"
systemctl start cloudreve.service
echo "===========安装完成，请访问http://IP:5212，使用下面生成的管理员账号和密码登录，登录后请修改管理员账号和密码==========="
echo "===========安装完成，请访问http://IP:5212，使用下面生成的管理员账号和密码登录，登录后请修改管理员账号和密码==========="
echo "===========安装完成，请访问http://IP:5212，使用下面生成的管理员账号和密码登录，登录后请修改管理员账号和密码==========="
journalctl -fu cloudreve.service
