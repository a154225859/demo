#!/bin/bash

# 停止并移除 Docker 容器
docker stop opl_worker
docker stop opl_scraper
docker rm opl_worker
docker rm opl_scraper

# 删除 machine-id 文件并重新生成
sudo rm -f /etc/machine-id
sudo systemd-machine-id-setup

# 切换到指定目录并启动 Docker Compose 服务
cd opl/ || exit 1
docker-compose up -d
