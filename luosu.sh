docker stop opl_worker
docker stop opl_scraper

docker rm opl_worker
docker rm opl_scraper

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install apt-transport-https ca-certificates gnupg lsb-release docker-ce docker-ce-cli containerd.io -y
sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d')/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 检查是否提供了参数
if [ -z "$1" ]; then
    echo "错误：没有提供参数，请提供 JSON 参数。"
    exit 1
fi

# 存储 JSON 参数
json_param="$1"

echo "keystore：$json_param"

# 删除 machine-id 文件并重新生成
rm -f /etc/machine-id
systemd-machine-id-setup

rm -rf opl

# 克隆 opl 仓库
echo "正在从 GitHub 克隆 opl 仓库..."
git clone https://github.com/a154225859/opl.git

mkdir -p ./opl/keystore

echo "$json_param" > ./opl/keystore/keystore.json

cd opl

echo "正在启动 docker-compose..."
docker-compose up -d

echo "安装完成。"
docker ps

# 启动INI
sudo systemctl start iniminer.service
