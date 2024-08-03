#!/bin/bash

install_quilibrium() {
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
	sed -i 's|listenGrpcMultiaddr: ""|listenGrpcMultiaddr: /ip4/0.0.0.0/tcp/8337|g' /root/ceremonyclient/node/.config/config.yml
	sed -i 's|listenRESTMultiaddr: ""|listenRESTMultiaddr: /ip4/0.0.0.0/tcp/8338|g' /root/ceremonyclient/node/.config/config.yml
}

check_rewards() {
	exec_start=$(sed -n 's/^ExecStart=\/root\/ceremonyclient\/node\///p' /lib/systemd/system/ceremonyclient.service) && cd /root/ceremonyclient/node && ./$exec_start --node-info
}

backup_store() {
        # 提示用户输入上传 URL
	read -p "请输入上传 URL: " upload_url
	
	exec_name=$(sed -n 's/^ExecStart=\/root\/ceremonyclient\/node\///p' /lib/systemd/system/ceremonyclient.service)
	# 进入工作目录
	cd /root/ceremonyclient/node
	
	# 获取 peerid
	peerid=$(./$exec_name -peer-id)
	peerid=$(echo $peerid | grep -o 'Qm[[:alnum:]]\+')
	echo "Peer ID: $peerid"
	
	# 进入 .config 目录
	cd /root/ceremonyclient/node/.config
	
	# 删除现有的 peerid.zip 文件（如果存在）
	rm -f *.zip
	
	# 压缩 .config 目录中的所有文件到 peerid.zip
	zip -r "${peerid}.zip" *
	
	# 上传文件
	file_path="/root/ceremonyclient/node/.config/${peerid}.zip"
	
	# 使用 curl 上传文件并显示进度条
	curl -F "file=@${file_path}" ${upload_url} --progress-bar
	
	# 打印上传成功信息
	echo "文件 ${peerid}.zip 已成功上传到 ${upload_url}"
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
        echo "8) 备份 Config 目录"
        echo "9) 退出"

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
                backup_store
                ;;
            9)  
                echo "退出..."
                break
                ;;
            *)
                echo "无效，请重新输入"
                ;;
        esac
    done
}

# 显示主菜单
show_quilibrium_menu
