#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/futu-opend}"
CONFIG_DIR="${CONFIG_DIR:-/etc/futu-opend}"
CONFIG_FILE="${CONFIG_FILE:-$CONFIG_DIR/FutuOpenD.xml}"
SERVICE_USER="${SERVICE_USER:-ubuntu}"
API_IP="${API_IP:-127.0.0.1}"
API_PORT="${API_PORT:-11111}"
BACKEND_ENV="${BACKEND_ENV:-/home/ubuntu/stock_web/backend/.env}"
START_SERVICE="${START_SERVICE:-false}"

download_url="${FUTU_OPEND_DOWNLOAD_URL:-}"
archive_path="${FUTU_OPEND_ARCHIVE:-}"

if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  SUDO="sudo"
fi

if [ -z "$archive_path" ] && [ -z "$download_url" ]; then
  cat >&2 <<'EOF'
FUTU_OPEND_ARCHIVE or FUTU_OPEND_DOWNLOAD_URL is required.

Download the official Ubuntu command line OpenD package from Futu, upload it to
the server, then rerun for example:

  FUTU_OPEND_ARCHIVE=/tmp/FutuOpenD_Ubuntu.tar.gz bash scripts/install_futu_opend_ubuntu.sh

Or pass a direct official download URL:

  FUTU_OPEND_DOWNLOAD_URL=https://... bash scripts/install_futu_opend_ubuntu.sh
EOF
  exit 2
fi

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
}

replace_or_append_env() {
  local file="$1"
  local key="$2"
  local value="$3"

  if grep -q "^${key}=" "$file"; then
    $SUDO sed -i "s|^${key}=.*|${key}=${value}|" "$file"
  else
    printf '%s=%s\n' "$key" "$value" | $SUDO tee -a "$file" >/dev/null
  fi
}

require_command tar
require_command find
require_command systemctl

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

if [ -n "$download_url" ]; then
  require_command curl
  archive_path="$tmp_dir/futu-opend-package"
  curl -fL --retry 3 --connect-timeout 15 --output "$archive_path" "$download_url"
fi

if [ ! -f "$archive_path" ]; then
  echo "OpenD package not found: $archive_path" >&2
  exit 1
fi

extract_dir="$tmp_dir/extract"
mkdir -p "$extract_dir"

case "$archive_path" in
  *.zip)
    require_command unzip
    unzip -q "$archive_path" -d "$extract_dir"
    ;;
  *.tar|*.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz)
    tar -xf "$archive_path" -C "$extract_dir"
    ;;
  *)
    if tar -tf "$archive_path" >/dev/null 2>&1; then
      tar -xf "$archive_path" -C "$extract_dir"
    else
      require_command unzip
      unzip -q "$archive_path" -d "$extract_dir"
    fi
    ;;
esac

binary_path="$(find "$extract_dir" -type f \( -name 'FutuOpenD' -o -name 'OpenD' \) | head -n 1)"
if [ -z "$binary_path" ]; then
  echo "Could not find FutuOpenD/OpenD binary in package." >&2
  exit 1
fi

source_dir="$(dirname "$binary_path")"
binary_name="$(basename "$binary_path")"
config_source="$(find "$source_dir" "$extract_dir" -type f \( -name 'FutuOpenD.xml' -o -name 'OpenD.xml' \) | head -n 1)"

if [ -z "$config_source" ]; then
  echo "Could not find FutuOpenD.xml/OpenD.xml in package." >&2
  exit 1
fi

$SUDO mkdir -p "$INSTALL_DIR" "$CONFIG_DIR" /var/log/futu-opend
$SUDO cp -a "$source_dir"/. "$INSTALL_DIR"/
$SUDO chmod +x "$INSTALL_DIR/$binary_name"

if [ ! -f "$CONFIG_FILE" ]; then
  $SUDO cp "$config_source" "$CONFIG_FILE"
  $SUDO chmod 600 "$CONFIG_FILE"
fi

$SUDO chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR" /var/log/futu-opend
$SUDO chown -R root:"$SERVICE_USER" "$CONFIG_DIR"
$SUDO chmod 750 "$CONFIG_DIR"
$SUDO chown root:"$SERVICE_USER" "$CONFIG_FILE"
$SUDO chmod 640 "$CONFIG_FILE"

$SUDO tee /usr/local/bin/futu-opend-start >/dev/null <<EOF
#!/usr/bin/env bash
set -euo pipefail
cd "$INSTALL_DIR"
exec "$INSTALL_DIR/$binary_name" \\
  -cfg_file="$CONFIG_FILE" \\
  -api_ip="$API_IP" \\
  -api_port="$API_PORT" \\
  -telnet_ip="127.0.0.1" \\
  -websocket_ip="127.0.0.1" \\
  -lang="chs" \\
  -console=1 \\
  -no_monitor=1
EOF
$SUDO chmod 755 /usr/local/bin/futu-opend-start

$SUDO tee /etc/systemd/system/futu-opend.service >/dev/null <<EOF
[Unit]
Description=Futu OpenD local market gateway
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/local/bin/futu-opend-start
Restart=on-failure
RestartSec=5
LimitNOFILE=65535
PrivateTmp=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

$SUDO systemctl daemon-reload

if [ -f "$BACKEND_ENV" ]; then
  replace_or_append_env "$BACKEND_ENV" FUTU_HOST "$API_IP"
  replace_or_append_env "$BACKEND_ENV" FUTU_PORT "$API_PORT"
  replace_or_append_env "$BACKEND_ENV" FUTU_CONNECT_TIMEOUT_SECONDS "2"
  $SUDO chmod 600 "$BACKEND_ENV" || true
fi

cat <<EOF
FutuOpenD files installed.

Binary directory:
  $INSTALL_DIR

Local config file:
  $CONFIG_FILE

Next steps on the server:
  1. Edit $CONFIG_FILE and set login_account plus login_pwd_md5 or login_pwd.
  2. Keep API listen address at 127.0.0.1 and port $API_PORT.
  3. Start service:
       sudo systemctl enable --now futu-opend
  4. Verify local-only listening:
       sudo ss -ltnp | grep ':$API_PORT'
  5. Restart backend:
       sudo systemctl restart stock-web-backend
       curl -sS http://127.0.0.1:8000/api/v1/futu/health
EOF

if [ "$START_SERVICE" = "true" ]; then
  $SUDO systemctl enable --now futu-opend
  $SUDO systemctl status futu-opend --no-pager
else
  $SUDO systemctl enable futu-opend >/dev/null
fi
