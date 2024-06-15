#!/bin/bash

echo "Stop the existing ceremonyclient service"
systemctl stop ceremonyclient.service

# Navigate to the ceremonyclient directory and update the repository
cd /root/ceremonyclient && git checkout main && git branch -D release && git remote set-url origin https://github.com/quilibriumnetwork/ceremonyclient.git && git pull && git checkout release

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    release_os="linux"
    if [[ $(uname -m) == "aarch64"* ]]; then
        release_arch="arm64"
    else
        release_arch="amd64"
    fi
else
    release_os="darwin"
    release_arch="arm64"
fi

cd /root/ceremonyclient/node
files=$(curl https://releases.quilibrium.com/release | grep $release_os-$release_arch)
new_release=false

for file in $files; do
    version=$(echo "$file" | cut -d '-' -f 2)
    if ! test -f "./$file"; then
        curl "https://releases.quilibrium.com/$file" > "$file"
        new_release=true
    fi
done

binary="node-$version-$release_os-$release_arch"
chmod +x node-$version-$release_os-$release_arch

echo "Create/update the systemd service file for ceremonyclient"
cat <<EOF > /lib/systemd/system/ceremonyclient.service
[Unit]
Description=Ceremony Client Go App Service

[Service]
Type=simple
Restart=always
RestartSec=5s
WorkingDirectory=/root/ceremonyclient/node
Environment=GOEXPERIMENT=arenas
ExecStart=/root/ceremonyclient/node/$binary

[Install]
WantedBy=multi-user.target
EOF

echo "Reload the systemd manager configuration"
systemctl daemon-reload

echo "Start the ceremonyclient service"
systemctl start ceremonyclient.service

echo "Ceremony Client has been updated and restarted successfully."
journalctl -fu ceremonyclient.service
