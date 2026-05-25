#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/home/ubuntu/stock_web}"
BACKEND_ENV="${BACKEND_ENV:-$APP_DIR/backend/.env}"
BACKUP_DIR="${BACKUP_DIR:-/home/ubuntu/stock_web_backups}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

if [ ! -f "$BACKEND_ENV" ]; then
  echo "Backend env file not found: $BACKEND_ENV" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$BACKEND_ENV"
set +a

if [ -z "${DATABASE_URL:-}" ]; then
  echo "DATABASE_URL is missing in $BACKEND_ENV" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

timestamp="$(date +%Y%m%d_%H%M%S)"
target="$BACKUP_DIR/stock_web_${timestamp}.dump"

pg_dump --format=custom --no-owner --no-acl --file="$target" "$DATABASE_URL"
chmod 600 "$target"

ln -sfn "$target" "$BACKUP_DIR/latest.dump"
find "$BACKUP_DIR" -type f -name 'stock_web_*.dump' -mtime +"$RETENTION_DAYS" -delete

echo "PostgreSQL backup created: $target"
