#!/bin/bash

if ! [ -x "$(command -v sudo)" ]; then
  echo "需要root权限执行脚本..." >&2
  exit 1
fi

echo "更新系统并安装工具..."
apt -q update
apt-get install git wget zip tar -y

cd /root
if [ ! -d "/root/.asdf" ]; then
  git clone https://github.com/asdf-vm/asdf.git /root/.asdf --branch v0.14.0
fi

if [ `grep -c "asdf.sh" /root/.bashrc` -ne '0' ];then
  echo "asdf config exists, skip..."
else
  chmod +x .asdf/asdf.sh
  chmod +x .asdf/completions/asdf.bash
  echo  '. $HOME/.asdf/asdf.sh' >> /root/.bashrc
  echo  '. $HOME/.asdf/completions/asdf.bash' >> /root/.bashrc
fi

source /root/.bashrc
source /root/.asdf/asdf.sh
source /root/.asdf/completions/asdf.bash

if [[ `asdf plugin list` =~ "golang" ]]; then
  echo "exists golang plugin, skip..."
else
  asdf plugin add golang https://github.com/asdf-community/asdf-golang.git
fi

if [ ! -d "/root/.asdf/installs/golang/1.20.14" ]; then
  asdf install golang 1.20.14
fi
if [ ! -d "/root/.asdf/installs/golang/1.22.1" ]; then
  asdf install golang 1.22.1
fi

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

cat <<EOF > /root/qlog.sh
journalctl -fu ceremonyclient.service
EOF
chmod +x /root/qlog.sh

cat <<EOF > /root/qinfo.sh
grpcurl -plaintext localhost:8337 quilibrium.node.node.pb.NodeService.GetNodeInfo
EOF
chmod +x /root/qinfo.sh

cat <<EOF > /root/qcount.sh
grpcurl -plaintext -max-msg-sz 50000000 localhost:8337 quilibrium.node.node.pb.NodeService.GetPeerInfo | grep peerId | wc -l
EOF
chmod +x /root/qcount.sh

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

echo "下载节点代码..."
cd /root && git clone https://github.com/QuilibriumNetwork/ceremonyclient.git
cd /root/ceremonyclient && asdf local golang 1.20.14

echo "下载最新frame进度..."
mkdir /root/ceremonyclient/node/.config && cd /root/ceremonyclient/node/.config
git clone https://github.com/a154225859/store.git

echo "安装Grpc..."
go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest

echo "编译二进制代码..."
cd /root/ceremonyclient/node && GOEXPERIMENT=arenas go clean -v -n -a ./...
rm /root/go/bin/node
cd /root/ceremonyclient/node && GOEXPERIMENT=arenas go install ./...

echo "让节点运行5分钟..."
cd /root/ceremonyclient/node && GOEXPERIMENT=arenas go run ./... > /dev/null 2>&1 &
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

sed -i 's|listenGrpcMultiaddr: ""|listenGrpcMultiaddr: "/ip4/127.0.0.1/tcp/8337"|g' /root/ceremonyclient/node/.config/config.yml
sed -i 's|listenRESTMultiaddr: ""|listenRESTMultiaddr: "/ip4/127.0.0.1/tcp/8338"|g' /root/ceremonyclient/node/.config/config.yml

GOEXPERIMENT=arenas go run ./... -peer-id
echo "配置完成，请保存上面的peerid,然后备份私钥..."
reboot
