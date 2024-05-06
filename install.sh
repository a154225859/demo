#!/bin/bash

# Define a function for displaying exit messages
exit_message() {
    echo "There was an error during the script execution and the process stopped. No worries!"
    echo "You can try to run the script from scratch again."
    echo "If you still receive an error, you may want to proceed manually, step by step instead of using the auto-installer."
}

# 确保脚本以 root 权限运行
if ! [ -x "$(command -v sudo)" ]; then
  echo "Sudo is not installed! This script requires sudo to run. Exiting..." >&2
  exit_message
  exit 1
fi

# 更新系统并安装基本工具
echo "更新系统并安装基本工具"
sudo apt -q update
sudo apt-get install git wget screen tar -y

# 安装 Go
if [[ $(go version) == *"go1.20.1"[1-4]* ]]; then
  echo "Go已经安装"
else
  echo "安装Go..."
  wget -4 https://go.dev/dl/go1.20.14.linux-amd64.tar.gz || { echo "下载Go安装包失败..."; exit_message; exit 1; }
  sudo tar -C /usr/local -xzf go1.20.14.linux-amd64.tar.gz || { echo "解压Go安装包失败..."; exit_message; exit 1; }
  sudo rm go1.20.14.linux-amd64.tar.gz || { echo "无法删除Go安装包..."; exit_message; exit 1; }
fi

# 配置 Go 环境变量
echo "配置 Go 环境变量"
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

# 创建并启用 swap 文件
if ! [ "$(sudo swapon -s)" ]; then
  echo "创建并启用 swap..."
  sudo mkdir /swap && sudo fallocate -l 24G /swap/swapfile && sudo chmod 600 /swap/swapfile || { echo "Failed to create swap space! Exiting..."; exit_message; exit 1; }
  sudo mkswap /swap/swapfile && sudo swapon /swap/swapfile || { echo "Failed to set up swap space! Exiting..."; exit_message; exit 1; }
  sudo bash -c 'echo "/swap/swapfile swap swap defaults 0 0" >> /etc/fstab' || { echo "Failed to update /etc/fstab! Exiting..."; exit_message; exit 1; }
fi

# 配置网络参数
echo "配置网络参数"
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

# 下载并初始化 ceremonyclient 仓库
echo "下载ceremonyclient代码..."
cd /root
git clone https://github.com/QuilibriumNetwork/ceremonyclient.git
cd /root/ceremonyclient/node

# 临时设置 Go 环境变量 - 多余，但它修复了 GO 命令未找到错误
export PATH=$PATH:/usr/local/go/bin 
export GOPATH=~/go

# 让节点运行5分钟后停止
echo "让节点运行5分钟。。。"
GOEXPERIMENT=arenas go run ./... > /dev/null 2>&1 &  # Redirect output to /dev/null
countdown() {
    secs=$1         # Assign the input argument (300) to the variable 'secs'
    while [ $secs -gt 0 ]; do
        printf "\r%02d:%02d remaining" $(($secs/60)) $(($secs%60)) # Print the remaining time (mm:ss) with a carriage return (\r) to overwrite the previous line
        sleep 1     # Wait for 1 second
        ((secs--))  # Decrement the 'secs' variable by 1
    done
    printf "\nDone!\n" # After the countdown completes, print "Done!" on a new line
}
countdown 300 || { echo "Failed to wait! Exiting..."; exit_message; exit 1; }

# 创建系统服务文件
echo "Creating systemd service for Ceremony Client Go App..."

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

# 启用并启动服务
systemctl enable ceremonyclient.service

# 清理 Go 编译缓存
echo "Cleaning Go build cache..."
cd /root/ceremonyclient/node
GOEXPERIMENT=arenas go clean -v -n -a ./...

# 删除旧的可执行文件
echo "Removing old executable..."
rm /root/go/bin/node

# 重新安装
echo "Reinstalling the node..."
GOEXPERIMENT=arenas go install ./...

reboot
