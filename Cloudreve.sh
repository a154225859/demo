# 检查系统架构
  ARCH=$(uname -m)
  if [[ "$ARCH" == "x86_64" ]]; then
    URL="http://49.13.194.189:8008/go1.20.14.linux-amd64.tar.gz"
  elif [[ "$ARCH" == "aarch64" ]]; then
    URL="http://49.13.194.189:8008/go1.20.14.linux-arm64.tar.gz"
  else
    echo "不支持的架构: $ARCH"
    exit 1
  fi

  # 下载安装包
  if wget -4 $URL; then
    echo "下载安装包成功..."
  else
    echo "下载安装包失败..."
    exit 1
  fi
  
  # 提取包文件名
  FILE_NAME=$(basename $URL)
  
  # 解压安装包
  if sudo tar -C /home/Cloudreve -xzf $FILE_NAME; then
    echo "解压安装包成功..."
  else
    echo "解压安装包失败..."
    exit 1
  fi

  # 删除安装包
  sudo rm $FILE_NAME
fi
