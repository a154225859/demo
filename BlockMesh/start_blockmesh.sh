#!/bin/bash

# 定义容器名称
container_name="blockmesh-cli-container"

# 检查 BlockMesh CLI 容器是否存在
if ! docker ps -a --format '{{.Names}}' | grep -q "$container_name"; then
    echo "容器不存在，请先安装 BlockMesh。"
    exit 1
fi

# 检查容器状态
container_status=$(docker inspect -f '{{.State.Status}}' "$container_name")

if [ "$container_status" == "running" ]; then
    echo "容器 '$container_name' 正在运行。"
else
    echo "容器 '$container_name' 正在启动..."
    docker start "$container_name"
    echo "容器 '$container_name' 已成功启动。"
fi
