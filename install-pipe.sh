#!/bin/bash

set -e

echo "🚀 Bắt đầu cài đặt Pipe Node..."

# 1. Tạo thư mục và tải file binary
mkdir -p /root/pipe/download_cache
cd /root/pipe
echo "⬇️  Đang tải binary..."
wget -q -O pop "https://dl.pipecdn.app/v0.2.8/pop"
chmod +x pop

# 2. Tạo Dockerfile
echo "🛠️  Tạo Dockerfile..."
cat <<EOF > Dockerfile
FROM ubuntu:22.04

RUN apt update && apt install -y \\
    libssl3 \\
    ca-certificates \\
    curl \\
    && rm -rf /var/lib/apt/lists/*

COPY pop /usr/local/bin/pop
RUN chmod +x /usr/local/bin/pop

ENTRYPOINT ["/usr/local/bin/pop"]
EOF

# 3. Build Docker image
echo "🐳 Build Docker image..."
docker build -t pipe-node .

# 4. Mở các port firewall
echo "🌐 Cấu hình tường lửa..."
ufw allow 8002/tcp
ufw allow 8003/tcp
ufw allow 80/tcp
ufw allow 443/tcp

# 5. Tạo systemd service
echo "📝 Tạo systemd service..."
cat <<EOF | sudo tee /etc/systemd/system/pipe.service > /dev/null
[Unit]
Description=Pipe Node Service (Docker)
After=network.target
Wants=network-online.target

[Service]
User=root
Group=root

ExecStartPre=-/usr/bin/docker rm -f pipe-pop

ExecStart=/usr/bin/docker run \\
  --name pipe-pop \\
  --network host \\
  -v /root/pipe/download_cache:/data \\
  pipe-node \\
  --ram 4 --max-disk 200 \\
  --cache-dir /data \\
  --pubKey Ef2okKBBcHd49HR1uUPXHNfULL6ZMotjQeX3E35bKJPQ

ExecStop=/usr/bin/docker stop pipe-pop

Restart=always
RestartSec=5
LimitNOFILE=65536
LimitNPROC=4096
StandardOutput=journal
StandardError=journal
SyslogIdentifier=dcdn-node

[Install]
WantedBy=multi-user.target
EOF

# 6. Kích hoạt dịch vụ
echo "🔁 Kích hoạt dịch vụ pipe..."
systemctl daemon-reload
systemctl enable pipe
systemctl restart pipe

echo "✅ Pipe Node đã được cài đặt thành công!"
docker exec -it pipe-pop /usr/local/bin/pop --status

