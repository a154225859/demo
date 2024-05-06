#!/bin/bash

if ! [ -x "$(command -v sudo)" ]; then
  echo "需要root权限执行脚本..." >&2
  exit 1
fi

echo "更新系统并安装工具..."
sudo apt -q update
sudo apt-get install git wget screen tar -y

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

echo "下载节点代码..."
cd /root
git clone https://github.com/QuilibriumNetwork/ceremonyclient.git
cd /root/ceremonyclient/node

# 临时设置 Go 环境变量 - 多余，但它修复了 GO 命令未找到错误
export PATH=$PATH:/usr/local/go/bin 
export GOPATH=~/go

echo "让节点运行5分钟后停止..."
GOEXPERIMENT=arenas go run ./... > /dev/null 2>&1 &
countdown() {
    secs=$1
    while [ $secs -gt 0 ]; do
        printf "\r%02d:%02d remaining" $(($secs/60)) $(($secs%60))
        sleep 1
        ((secs--))
    done
    printf "\nDone!\n"
}
countdown 300 || { echo "Failed to wait! Exiting..."; exit 1; }

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

echo "编译二进制代码..."
cd /root/ceremonyclient/node
GOEXPERIMENT=arenas go clean -v -n -a ./...
rm /root/go/bin/node
GOEXPERIMENT=arenas go install ./...
echo "启动服务..."
sudo systemctl start ceremonyclient.service
cd /root/ceremonyclient/node
GOEXPERIMENT=arenas go run ./... -peer-id
echo "配置完成，请保存上面的peerid,然后备份私钥..."
