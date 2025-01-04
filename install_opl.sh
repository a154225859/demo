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
        	sudo usermod -aG docker $USER
	 	newgrp docker
        echo "Docker installation complete."
    else
        echo "Docker is already installed. "
    fi
