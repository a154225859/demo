#!/bin/bash

# 从Go文件中提取版本号
version=$(cat /root/ceremonyclient/node/config/version.go | grep -A 1 "func GetVersion() \[\]byte {" | grep -Eo '0x[0-9a-fA-F]+' | xargs printf "%d.%d.%d")

# 根据操作系统类型和架构确定二进制文件路径
case "$OSTYPE" in
    linux-gnu*)
        if [[ $(uname -m) == x86* ]]; then
            binary="node-$version-linux-amd64"
        else
            binary="node-$version-linux-arm64"
        fi
        ;;
    darwin*)
        binary="node-$version-darwin-arm64"
        ;;
    *)
        echo "不支持的操作系统，请从源码构建"
        exit 1
        ;;
esac

# 检查二进制文件是否存在且可执行
cd /root/ceremonyclient/node
if [[ -x "$binary" ]]; then
    # 执行二进制文件并提取Peer ID
    output=$(./"$binary" -peer-id)
    peerid=$(echo "$output" | grep -o 'Qm[^ ]*')
    echo "提取的Peer ID: $peerid"
else
    echo "二进制文件未找到或不可执行: $binary"
    exit 1
fi
