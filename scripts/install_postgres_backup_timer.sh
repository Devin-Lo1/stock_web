#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/home/ubuntu/stock_web}"
BACKUP_DIR="${BACKUP_DIR:-/home/ubuntu/stock_web_backups}"
BACKUP_TIME="${BACKUP_TIME:-03:30:00}"

sudo tee /etc/systemd/system/stock-web-db-backup.service >/dev/null <<EOF
[Unit]
Description=Stock Web PostgreSQL backup
After=postgresql.service

[Service]
Type=oneshot
User=ubuntu
Environment=APP_DIR=$APP_DIR
Environment=BACKUP_DIR=$BACKUP_DIR
ExecStart=/usr/bin/bash $APP_DIR/scripts/backup_postgres.sh
EOF

sudo tee /etc/systemd/system/stock-web-db-backup.timer >/dev/null <<EOF
[Unit]
Description=Run Stock Web PostgreSQL backup daily

[Timer]
OnCalendar=*-*-* $BACKUP_TIME
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now stock-web-db-backup.timer
sudo systemctl start stock-web-db-backup.service
sudo systemctl status stock-web-db-backup.service --no-pager
sudo systemctl list-timers stock-web-db-backup.timer --no-pager
