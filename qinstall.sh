#!/bin/bash

# 检查是否为root用户
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# 创建挂载点
mkdir -p /quilibrium

# 检查UUID并保存到变量中
UUID=$(blkid -o value -s UUID /dev/vdb1)

# 挂载磁盘
mount /dev/vdb1 /quilibrium

# 检查/etc/fstab中是否已有相应条目，避免重复添加
if grep -qs '/quilibrium ' /etc/fstab; then
   echo "/quilibrium already exists in /etc/fstab"
else
   # 更新/etc/fstab以实现自动挂载
   echo "UUID=$UUID /quilibrium ext4 defaults 0 2" >> /etc/fstab
   echo "/dev/vdb1 is now set to auto-mount to /quilibrium"
fi

# 测试fstab配置并重新挂载
mount -a

# 结束脚本
echo "Script completed successfully."
