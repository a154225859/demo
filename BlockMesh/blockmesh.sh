#!/bin/bash

# 菜单显示函数
show_menu() {
    echo "请选择一个操作："
    echo "1) 安装 BlockMesh"
    echo "2) 更新 BlockMesh"
    echo "3) 启动 BlockMesh"
    echo "4) 停止 BlockMesh"
    echo "5) 查看日志"
    echo "6) 退出"
}

# 执行脚本的函数
execute_script() {
    local script_url=$1
    echo "执行脚本：$script_url"
    curl -fsSL "$script_url" | bash
}

# 主循环
while true; do
    show_menu
    read -p "请输入您的选择（1-6）：" choice

    case $choice in
        1)
            # 安装 BlockMesh
            execute_script "https://raw.githubusercontent.com/a154225859/demo/refs/heads/main/BlockMesh/install_blockmesh.sh"
            ;;
        2)
            # 更新 BlockMesh
            echo "没写"
            #execute_script "https://github.com/a154225859/demo/blob/main/update_blockmesh.sh"
            ;;
        3)
            # 启动 BlockMesh
            echo "没写"
            #execute_script "https://github.com/a154225859/demo/blob/main/start_blockmesh.sh"
            ;;
        4)
            # 停止 BlockMesh
            echo "没写"
            #execute_script "https://github.com/a154225859/demo/blob/main/stop_blockmesh.sh"
            ;;
        5)
            # 查看日志
            echo "没写"
            #execute_script "https://github.com/a154225859/demo/blob/main/log_blockmesh.sh"
            ;;
        6)
            # 退出
            echo "退出程序。"
            exit 0
            ;;
        *)
            echo "无效的选择，请输入 1 到 6 之间的数字。"
            ;;
    esac

    echo
done