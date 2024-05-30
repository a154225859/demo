#!/bin/sh

# 提示用户输入配置变量
read -p "请输入 SOCKS 端口号: " socks_port
read -p "请输入 SOCKS 用户名: " socks_user
read -sp "请输入 SOCKS 密码: " socks_pass
echo

# 重置 iptables 规则
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -t nat -F
iptables -t mangle -F
iptables -F
iptables -X
iptables-save

# 获取 IP 地址
ips=($(hostname -I))

# 安装 Xray
wget -O /usr/local/bin/xray http://154936322.sxmir.com/xray
chmod +x /usr/local/bin/xray

# 创建 Xray systemd 服务文件
cat <<EOF > /etc/systemd/system/xray.service
[Unit]
Description=The Xray Proxy 服务
After=network-online.target

[Service]
ExecStart=/usr/local/bin/xray -c /etc/xray/serve.toml
ExecStop=/bin/kill -s QUIT \$MAINPID
Restart=always
RestartSec=15s

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 并启用 Xray 服务
systemctl daemon-reload
systemctl enable xray

# 创建 Xray 配置目录
mkdir -p /etc/xray

# 创建 Xray 配置文件
echo -n "" > /etc/xray/serve.toml
for ip in "${ips[@]}"; do
cat <<EOF >> /etc/xray/serve.toml
[[inbounds]]
listen = "$ip"
port = $socks_port
protocol = "socks"
tag = "inbound_$ip"
[inbounds.settings]
auth = "password"
udp = true
ip = "$ip"
[[inbounds.settings.accounts]]
user = "$socks_user"
pass = "$socks_pass"

[[routing.rules]]
type = "field"
inboundTag = "inbound_$ip"
outboundTag = "outbound_$ip"

[[outbounds]]
sendThrough = "$ip"
protocol = "freedom"
tag = "outbound_$ip"
EOF
done

# 启动 Xray 服务
systemctl stop xray
systemctl start xray
