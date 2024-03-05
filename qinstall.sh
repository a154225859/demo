#!/bin/bash

# 数据盘的设备名称
data_disk="/dev/vdb"
data_partition="${data_disk}1"

# 创建新分区
echo -e "n\np\n1\n\n\nt\n83\nw" | sudo fdisk "$data_disk"
sudo partprobe

# 格式化新分区
sudo mkfs.ext4 "$data_partition"

# 挂载新分区
sudo mkdir /mnt/new_partition
sudo mount "$data_partition" /mnt/new_partition

# 复制数据
sudo rsync -avx /path/to/source/ /mnt/new_partition/

# 更新 /etc/fstab
echo "$data_partition    /path/to/mountpoint    ext4    defaults    0    0" | sudo tee -a /etc/fstab

# 卸载原数据盘
sudo umount /path/to/old_partition

# 扩展系统盘
sudo parted /dev/vda resizepart 1 100%

# 扩展文件系统
sudo resize2fs /dev/vda1

echo "操作完成。请检查是否有任何错误。"
