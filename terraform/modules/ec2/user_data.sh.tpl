#!/bin/bash
set -e

# ── Swap 4GB ──────────────────────────────────────────────────────────────
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# ── 시스템 패키지 ──────────────────────────────────────────────────────────
dnf update -y
dnf install -y mariadb105-server nginx git python3.12 python3.12-pip

# ── Node.js 20 ────────────────────────────────────────────────────────────
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install -y nodejs

# ── MariaDB 설정 ───────────────────────────────────────────────────────────
systemctl enable mariadb
systemctl start mariadb

# 메모리 튜닝 + 외부 접속 허용 (Lambda enricher → EC2 MariaDB)
cat > /etc/my.cnf.d/dndn.cnf << 'MARIACONF'
[mysqld]
bind-address            = 0.0.0.0
innodb_buffer_pool_size = 128M
max_connections         = 50
MARIACONF

systemctl restart mariadb

# DB + 사용자 생성
mysql -e "CREATE DATABASE IF NOT EXISTS ${db_name} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS '${db_user}'@'%' IDENTIFIED BY '${db_password}';"
mysql -e "GRANT ALL PRIVILEGES ON ${db_name}.* TO '${db_user}'@'%';"
mysql -e "FLUSH PRIVILEGES;"

# ── 앱 디렉토리 ────────────────────────────────────────────────────────────
mkdir -p /opt/dndn/{api,web}
chown ec2-user:ec2-user /opt/dndn /opt/dndn/api /opt/dndn/web

# ── nginx 설정 (HTTP → API:8000 / Web:3000 프록시) ─────────────────────────
cat > /etc/nginx/conf.d/dndn.conf << 'NGINXCONF'
server {
    listen 80;
    server_name _;

    location /api/ {
        proxy_pass         http://127.0.0.1:8000/;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    }

    location / {
        proxy_pass         http://127.0.0.1:3000;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    }
}
NGINXCONF

systemctl enable nginx
systemctl start nginx

# ── systemd 서비스 파일 (코드 배포 후 enable + start) ─────────────────────

cat > /etc/systemd/system/dndn-api.service << 'SVCEOF'
[Unit]
Description=DnDn API Server (FastAPI)
After=network.target mariadb.service
Requires=mariadb.service

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/dndn/api
EnvironmentFile=/opt/dndn/api/.env
ExecStart=/opt/dndn/api/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --workers 2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

cat > /etc/systemd/system/dndn-worker.service << 'SVCEOF'
[Unit]
Description=DnDn Worker
After=network.target mariadb.service dndn-api.service

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/dndn/api
EnvironmentFile=/opt/dndn/api/.env
ExecStart=/opt/dndn/api/venv/bin/python -m apps.worker.main
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

cat > /etc/systemd/system/dndn-reporter.service << 'SVCEOF'
[Unit]
Description=DnDn Reporter
After=network.target mariadb.service

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/dndn/api
EnvironmentFile=/opt/dndn/api/.env
ExecStart=/opt/dndn/api/venv/bin/python -m apps.report.main
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

cat > /etc/systemd/system/dndn-web.service << 'SVCEOF'
[Unit]
Description=DnDn Web (Next.js)
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/dndn/web
ExecStart=/usr/bin/node server.js
Environment=PORT=3000
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
# 코드 배포 후 활성화:
# sudo systemctl enable --now dndn-api dndn-worker dndn-reporter dndn-web
