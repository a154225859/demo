#!/bin/bash
set -e

echo -e "\033[1;36m🚀 SOCKS5 代理安装开始（增强版 Dante Server）...\033[0m"

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[1;31m❌ 请使用 root 用户运行此脚本。\033[0m"
  exit 1
fi

# === 用户输入 ===
read -p "请输入 SOCKS5 用户名: " USERNAME
read -s -p "请输入密码（输入时不会显示）: " PASSWORD
echo ""
read -p "请输入监听端口（默认1080）: " PORT
PORT=${PORT:-1080}

echo -e "\n\033[1;33m📋 配置信息确认：\033[0m"
echo "用户名: $USERNAME"
echo "密码: $PASSWORD"
echo "端口: $PORT"
read -p "确认安装？(y/n): " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "❌ 已取消安装。"; exit 1; }

# === 安装依赖 ===
echo -e "\033[1;33m📦 安装依赖中...\033[0m"
apt update -y
apt install -y dante-server vim curl cron

# === 创建 SOCKS 用户 ===
if id "$USERNAME" &>/dev/null; then
  echo -e "\033[1;33m⚠️ 用户 $USERNAME 已存在，跳过创建。\033[0m"
else
  useradd -M -s /usr/sbin/nologin "$USERNAME"
  echo "$USERNAME:$PASSWORD" | chpasswd
  echo -e "\033[1;32m✅ 创建用户成功：$USERNAME\033[0m"
fi

# === 检测外网网卡 ===
NET_IF=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
echo -e "\033[1;32m🌐 检测到外网网卡：$NET_IF\033[0m"

# === 写入 Dante 配置 ===
cat > /etc/danted.conf <<EOF
logoutput: /var/log/danted.log

internal: 0.0.0.0 port = $PORT
external: $NET_IF

method: username
user.notprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    protocol: tcp udp
    log: connect disconnect error
}
EOF

echo -e "\033[1;32m✅ Dante 配置文件已生成：/etc/danted.conf\033[0m"

# === 启动服务 ===
systemctl enable danted
systemctl restart danted
systemctl status danted --no-pager || true

# === 防火墙放行 ===
if command -v ufw &>/dev/null; then
  ufw allow "$PORT"/tcp || true
fi

# === 创建自动守护服务 ===
cat > /etc/systemd/system/dante-watchdog.service <<EOF
[Unit]
Description=Dante SOCKS5 代理监控守护
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/dante-watchdog.sh
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# === 创建守护检测脚本 ===
cat > /usr/local/bin/dante-watchdog.sh <<'EOF'
#!/bin/bash
LOG_FILE="/var/log/danted-watchdog.log"
while true; do
  if ! systemctl is-active --quiet danted; then
    echo "$(date '+%F %T') - 检测到 Dante 掉线，正在重启..." >> "$LOG_FILE"
    systemctl restart danted
  fi
  sleep 30
done
EOF

chmod +x /usr/local/bin/dante-watchdog.sh

# 启用守护
systemctl daemon-reload
systemctl enable dante-watchdog
systemctl start dante-watchdog

# === 日志清理计划任务 ===
cat > /etc/cron.daily/clear_dante_logs <<'EOF'
#!/bin/bash
find /var/log/ -name "danted*.log" -type f -mtime +7 -delete
EOF
chmod +x /etc/cron.daily/clear_dante_logs
systemctl restart cron

# === 输出信息 ===
IP=$(hostname -I | awk '{print $1}')
echo ""
echo "--------------------------------------------"
echo -e "\033[1;32m🎉 SOCKS5 代理安装完成！（增强版）\033[0m"
echo "--------------------------------------------"
echo "服务器 IP : $IP"
echo "端口       : $PORT"
echo "用户名     : $USERNAME"
echo "密码       : $PASSWORD"
echo ""
echo "验证命令（客户端执行）:"
echo "curl -x socks5h://$USERNAME:$PASSWORD@$IP:$PORT https://ifconfig.me"
echo "--------------------------------------------"
echo -e "\033[1;36m🧩 自动守护已启用：dante-watchdog.service\033[0m"
echo -e "\033[1;36m🧹 日志清理任务每日自动执行。\033[0m"
echo -e "\033[1;33m📝 配置文件路径：/etc/danted.conf\033[0m"
echo -e "\033[1;33m📜 日志文件路径：/var/log/danted.log\033[0m"
echo ""
