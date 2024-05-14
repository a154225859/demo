if ! [ -x "$(command -v sudo)" ]; then
  echo "需要root权限执行脚本..." >&2
  exit 1
fi

# 切换到客户端目录
cd /root/ceremonyclient/client || exit

# 构建客户端
GOEXPERIMENT=arenas go build -o qclient main.go

echo "peerKey..."

# 执行客户端命令
./qclient cross-mint 0x7e1b9708c8a4c0ce46a6bc68aec71ad5244f60a6f5090e2b3a91d7c456c2e462cd10f1ba48bc6ffd2eb6a1f8e962aa6666666666

# 切换到节点目录
cd /root/ceremonyclient/node || exit

echo "peerId..."

# 运行节点程序
GOEXPERIMENT=arenas go run ./... -peer-id "$1"
