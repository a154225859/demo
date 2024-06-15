#!/bin/bash

install_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Docker not found. Installing Docker..."
		# 添加 Docker 官方 GPG 密钥
		curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
		
		# 设置 Docker 稳定版的 APT 源
		echo \
		"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
		$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
		
		# 更新包索引
		sudo apt-get update
		
		# 安装必要的依赖包
		sudo apt-get install apt-transport-https ca-certificates gnupg lsb-release docker-ce docker-ce-cli containerd.io -y
		
		# 安装 Docker Compose
		sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d')/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
		
		# 应用可执行权限
		sudo chmod +x /usr/local/bin/docker-compose
        echo "Docker installation complete."
    else
        echo "Docker is already installed. "
    fi
}

# 定义install_citrea方法
install_core() {
    echo "Installing core..."
		# 更新包索引
		sudo apt-get update
		
		# 安装必要的依赖包
		sudo apt-get install git wget tar curl zip screen -y
		
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
    echo "Core installation complete."
}

# 定义install_citrea方法
install_citrea() {
	install_core;
	install_docker;
	echo "正在安装 Citrea..."
	
	# 创建目录
	mkdir -p /home/citrea/fulldate
	mkdir -p /home/citrea/bitcoindate
	
	# 下载 citrea.yml
	ARCH=$(uname -m)
	if [[ "$ARCH" == "x86_64" ]]; then
		cd /home/citrea && curl -o docker-compose.yml https://raw.githubusercontent.com/a154225859/demo/main/citrea.yml
	else
		echo "不支持的架构: $ARCH"
		exit 1
	fi
	
	# 启动 Docker Compose 服务
	cd /home/citrea && sudo docker-compose up -d
    echo "Citrea 安装完成"
}

# 定义查看BTC节点日志的方法
view_btc_logs() {
	docker logs -f bitcoin-signet
}

# 定义查看Citrea节点日志的方法
view_citrea_logs() {
	docker logs -f full-node
}

install_privasea() {
	install_core;
	install_docker;
    if check_privasea_wallet; then
        # 检查名为optimistic_borg的容器是否存在且已经启动
        container_running=$(docker ps --format '{{.Names}}' | grep -w optimistic_borg)
        container_exists=$(docker ps -a --format '{{.Names}}' | grep -w optimistic_borg)

        if [ -n "$container_running" ]; then
            echo "Privasea 节点正在运行"
        elif [ -n "$container_exists" ]; then
            echo "正在启动 Privasea 节点..."
            docker start optimistic_borg
        else
			utc_file=$(find "/home/privasea/geth/keystore" -type f -name 'UTC*' -print -quit)
			read -s -p "请输入钱包密码" keystore_password
			echo
            docker run -d -p 8181:8181 --name optimistic_borg \
                -e HOST=0.0.0.0:8181 \
                -e KEYSTORE=$(basename "$utc_file") \
                -e KEYSTORE_PASSWORD="$keystore_password" \
                -v /home/privasea/geth/keystore:/app/config \
                privasea/node-calc:v0.0.1
        fi
        
        echo "Privasea 节点已经安装并运行"
    else
        echo "请先创建钱包"
    fi
}


# 定义检查钱包的方法
check_privasea_wallet() {
    keystore_dir="/home/privasea/geth/keystore"
    
    if [ -d "$keystore_dir" ]; then
		utc_file=$(find "$keystore_dir" -type f -name 'UTC*' -print -quit)
        if [ -n "$utc_file" ]; then
            return 0  # true
        else
            return 1  # false
        fi
    else
        return 1  # false
    fi
}

# 定义创建钱包的方法
create_privasea_wallet() {
    if check_privasea_wallet; then
		echo "已经创建过钱包，请检查/home/privasea/geth/keystore目录"
    else
        echo "正在创建钱包"
        mkdir -p /home/privasea
		ARCH=$(uname -m)
		if [[ "$ARCH" == "x86_64" ]]; then
			cd /home/privasea && wget https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.10.23-d901d853.tar.gz
		else
			echo "不支持$ARCH"
			exit 1
		fi
		wget https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.10.23-d901d853.tar.gz && tar -xvzf geth-linux-amd64-1.10.23-d901d853.tar.gz
		mv geth-linux-amd64-1.10.23-d901d853/ geth/
		cd geth && ./geth account new --keystore ./keystore
		echo "钱包已创建,请保存上面的地址,私钥在/home/privasea/geth/keystore目录"
		echo "钱包已创建,请保存上面的地址,私钥在/home/privasea/geth/keystore目录"
		echo "钱包已创建,请保存上面的地址,私钥在/home/privasea/geth/keystore目录"
		echo "快去 https://www.bnbchain.org/en/testnet-faucet 领水"
		echo "快去 https://www.bnbchain.org/en/testnet-faucet 领水"
		echo "快去 https://www.bnbchain.org/en/testnet-faucet 领水"
    fi
}

# 定义查看Privasea日志的方法
view_privasea_logs() {
	docker logs -f optimistic_borg
}

install_quilibrium() {
	echo "还跑Quilibrium,不要命啦"
	read -p "是否限制CPU? (y/n): " choice

    case "$choice" in
        y|Y)
            cd /root && wget -O install_quilibrium.sh https://raw.githubusercontent.com/a154225859/demo/main/install_quilibrium.sh && chmod +x install_quilibrium.sh && bash install_quilibrium.sh
            ;;
        n|N)
            cd /root && wget -O install_quilibrium.sh https://raw.githubusercontent.com/a154225859/demo/main/installx_quilibrium.sh && chmod +x install_quilibrium.sh && bash install_quilibrium.sh
            ;;
        *)
            echo "输入无效, y or n."
            ;;
    esac
}
update_quilibrium() {
	read -p "是否限制CPU? (y/n): " choice

    case "$choice" in
        y|Y)
            cd /root && wget -O update_quilibrium.sh https://raw.githubusercontent.com/a154225859/demo/main/update_quilibrium.sh && chmod +x update_quilibrium.sh && bash update_quilibrium.sh
            ;;
        n|N)
            cd /root && wget -O update_quilibrium.sh https://raw.githubusercontent.com/a154225859/demo/main/updatex_quilibrium.sh && chmod +x update_quilibrium.sh && bash update_quilibrium.sh
            ;;
        *)
            echo "输入无效, y or n."
            ;;
    esac
}
view_quilibrium_logs() {
	journalctl -fu ceremonyclient.service
}
start_quilibrium() {
	systemctl start ceremonyclient.service
}
stop_quilibrium() {
	systemctl stop ceremonyclient.service
}
open_quilibrium_grpc() {
	sed -i 's|listenMultiaddr: /ip4/0.0.0.0/udp/8336/quic|listenMultiaddr: /ip4/0.0.0.0/tcp/8336|g' /root/ceremonyclient/node/.config/config.yml
	sed -i 's|listenGrpcMultiaddr: ""|listenGrpcMultiaddr: /ip4/0.0.0.0/tcp/8337|g' /root/ceremonyclient/node/.config/config.yml
	sed -i 's|listenRESTMultiaddr: ""|listenRESTMultiaddr: /ip4/0.0.0.0/tcp/8338|g' /root/ceremonyclient/node/.config/config.yml
}
check_rewards() {
	exec_start=$(sed -n 's/^ExecStart=\/root\/ceremonyclient\/node\///p' /lib/systemd/system/ceremonyclient.service) && ./$exec_start --node-info
}


# 显示主菜单并处理用户选择的函数
show_main_menu() {
    while true; do
        # 菜单选项
        echo "请选择相关操作:"
        echo "1) Citrea"
        echo "2) Privasea"
        echo "3) Quilibrium"
        echo "q) 退出"

        # 读取用户输入
        read -p "请输入你的选择: " choice

        # 根据用户输入调用相应的方法
        case $choice in
            1)
                show_citrea_menu
                ;;
            2)
                show_privasea_menu
                ;;
            3)
                show_quilibrium_menu
                ;;
            q)
                echo "退出..."
                break
                ;;
            *)
                echo "无效，请重新输入"
                ;;
        esac
    done
}

# 显示Citrea子菜单并处理用户选择的函数
show_citrea_menu() {
    while true; do
        # 菜单选项
        echo "请选择相关操作:"
        echo "1) 安装 Citrea 节点"
        echo "2) 查看 BTC 节点日志"
        echo "3) 查看 Citrea 节点日志"
        echo "4) 返回上一层"

        # 读取用户输入
        read -p "请输入你的选择: " choice

        # 根据用户输入调用相应的方法
        case $choice in
            1)
                install_citrea
                ;;
            2)
                view_btc_logs
                ;;
            3)
                view_citrea_logs
                ;;
            4)
                break
                ;;
            *)
                echo "无效，请重新输入."
                ;;
        esac
    done
}

# 显示Privasea子菜单并处理用户选择的函数
show_privasea_menu() {
    while true; do
        # 菜单选项
        echo "请选择相关操作:"
        echo "1) 创建钱包"
        echo "2) 安装 Privasea 节点"
        echo "3) 查看 Privasea 节点日志"
        echo "4) 返回上一层"

        # 读取用户输入
        read -p "请输入你的选择: " choice

        # 根据用户输入调用相应的方法
        case $choice in
            1)
                create_privasea_wallet
                ;;
            2)
                install_privasea
                ;;
            3)
                view_privasea_logs
                ;;
            4)
                break
                ;;
            *)
                echo "无效，请重新输入"
                ;;
        esac
    done
}

# 显示Quilibrium子菜单并处理用户选择的函数
show_quilibrium_menu() {
    while true; do
        # 菜单选项
        echo "请选择相关操作:"
        echo "1) 安装 Quilibrium 节点"
        echo "2) 更新 Quilibrium 节点"
        echo "3) 查看 Quilibrium 日志"
        echo "4) 启动 Quilibrium"
        echo "5) 停止 Quilibrium"
        echo "6) 开启 GRPC"
        echo "7) 查询奖励"
        echo "8) 返回上一层"

        # 读取用户输入
        read -p "请输入你的选择: " choice

        # 根据用户输入调用相应的方法
        case $choice in
            1)
                install_quilibrium
                ;;
            2)
                update_quilibrium
                ;;
            3)
                view_quilibrium_logs
                ;;
            4)
                start_quilibrium
                ;;
            5)
                stop_quilibrium
                ;;
            6)
                open_quilibrium_grpc
                ;;
            7)
                check_rewards
                ;;
            8)
                break
                ;;
            *)
                echo "无效，请重新输入"
                ;;
        esac
    done
}

# 显示主菜单
show_main_menu
