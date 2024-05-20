#!/bin/bash

if ! [ -x "$(command -v sudo)" ]; then
  echo "需要root权限执行脚本..." >&2
  exit 1
fi

cd /root 

echo "更新系统并安装工具..."
apt -q update
apt-get install git wget zip tar -y

if ! [ "$(sudo swapon -s)" ]; then
  echo "创建swap..."
  sudo mkdir /swap && sudo fallocate -l 24G /swap/swapfile && sudo chmod 600 /swap/swapfile || { echo "Failed to create swap space! Exiting..."; exit 1; }
  sudo mkswap /swap/swapfile && sudo swapon /swap/swapfile || { echo "Failed to set up swap space! Exiting..."; exit 1; }
  sudo bash -c 'echo "/swap/swapfile swap swap defaults 0 0" >> /etc/fstab' || { echo "Failed to update /etc/fstab! Exiting..."; exit 1; }
fi

echo "配置网络参数..."
if [[ $(grep ^"net.core.rmem_max=600000000"$ /etc/sysctl.conf) ]]; then
  echo "\net.core.rmem_max=600000000\" found inside /etc/sysctl.conf, skipping..."
else
  echo -e "\n# Change made to increase buffer sizes for better network performance for ceremonyclient\nnet.core.rmem_max=600000000" | sudo tee -a /etc/sysctl.conf > /dev/null
fi
if [[ $(grep ^"net.core.wmem_max=600000000"$ /etc/sysctl.conf) ]]; then
  echo "\net.core.wmem_max=600000000\" found inside /etc/sysctl.conf, skipping..."
else
  echo -e "\n# Change made to increase buffer sizes for better network performance for ceremonyclient\nnet.core.wmem_max=600000000" | sudo tee -a /etc/sysctl.conf > /dev/null
fi
sudo sysctl -p

cat <<EOF > /root/qlog.sh
journalctl -fu ceremonyclient.service
EOF
chmod +x /root/qlog.sh

cat <<EOF > /root/qinfo.sh
grpcurl -plaintext localhost:8337 quilibrium.node.node.pb.NodeService.GetNodeInfo
EOF
chmod +x /root/qinfo.sh

cat <<EOF > /root/qupdate.sh
echo "Stopping Ceremony Client service..."
systemctl stop ceremonyclient.service
cd /root/ceremonyclient
git fetch origin
git merge origin
cd /root/ceremonyclient/node && GOEXPERIMENT=arenas go clean -v -n -a ./...
rm /root/go/bin/node
GOEXPERIMENT=arenas go install ./...
echo "Restarting Ceremony Client service..."
systemctl start ceremonyclient.service
echo "Ceremony Client has been updated and restarted successfully."
EOF
chmod +x /root/qupdate.sh

cat <<EOF > /root/qupkey.sh
read -p "请输入服务器ip: " IP_ADDRESS
read -p "请输入服务器端口: " PORT

# 获取 peerid
cd /root/ceremonyclient/node
peerid=$(GOEXPERIMENT=arenas go run ./... -peer-id)

# 压缩文件
cd /root/ceremonyclient/node/.config/
zip "${peerid}.zip" config.yml keys.yml

# 上传文件
curl -F "file=@${peerid}.zip" http://${IP_ADDRESS}:${PORT}
EOF
chmod +x /root/qupkey.sh

echo "将节点设置为系统服务..."
cat <<EOF > /lib/systemd/system/ceremonyclient.service
[Unit]
Description=Ceremony Client Go App Service

[Service]
Type=simple
Restart=always
RestartSec=5s
WorkingDirectory=/root/ceremonyclient/node
Environment=GOEXPERIMENT=arenas
ExecStart=/root/go/bin/node ./..

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable ceremonyclient.service

# 安装 Go
if [[ $(go version) == *"go1.20.1"[1-4]* ]]; then
  echo "Go已经安装..."
else
  echo "安装Go..."
  wget -4 https://go.dev/dl/go1.20.14.linux-amd64.tar.gz || { echo "下载Go安装包失败..."; exit 1; }
  sudo tar -C /usr/local -xzf go1.20.14.linux-amd64.tar.gz || { echo "解压Go安装包失败..."; exit 1; }
  sudo rm go1.20.14.linux-amd64.tar.gz
fi
echo "配置 Go 环境变量..."
# Check if PATH is already set
if grep -q 'export PATH=$PATH:/usr/local/go/bin' ~/.bashrc; then
    echo "PATH already set in ~/.bashrc."
else
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    echo "PATH set in ~/.bashrc."
fi
# Check if GOPATH is already set
if grep -q "export GOPATH=$HOME/go" ~/.bashrc; then
    echo "GOPATH already set in ~/.bashrc."
else
    echo "export GOPATH=$HOME/go" >> ~/.bashrc
    echo "GOPATH set in ~/.bashrc."
fi
# Source .bashrc to apply changes
source ~/.bashrc
sleep 1  # Add a 1-second delay

# 临时设置 Go 环境变量 - 多余，但它修复了 GO 命令未找到错误
export PATH=$PATH:/usr/local/go/bin 
export GOPATH=~/go

echo "下载节点代码..."
cd /root && git clone https://github.com/QuilibriumNetwork/ceremonyclient.git
cd /root/ceremonyclient/node && GOEXPERIMENT=arenas go clean -v -n -a ./...
rm /root/go/bin/node
cd /root/ceremonyclient/node && GOEXPERIMENT=arenas go install ./...
echo "完成....."
