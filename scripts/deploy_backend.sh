#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/home/ubuntu/stock_web}"
BACKEND_DIR="$APP_DIR/backend"

cd "$APP_DIR"
git pull --ff-only

cd "$BACKEND_DIR"
if [ ! -d ".venv" ]; then
  python3 -m venv .venv
fi

./.venv/bin/python -m pip install --upgrade pip
./.venv/bin/pip install -r requirements.txt
./.venv/bin/python -c "from app.database import init_database; init_database(seed_defaults=False); print('database initialized')"

sudo systemctl restart stock-web-backend
sleep 2

curl -fsS http://127.0.0.1:8000/health
echo
sudo systemctl status stock-web-backend --no-pager
