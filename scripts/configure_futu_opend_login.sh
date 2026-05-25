#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${CONFIG_FILE:-/etc/futu-opend/FutuOpenD.xml}"
API_IP="${API_IP:-127.0.0.1}"
API_PORT="${API_PORT:-11111}"

login_account="${FUTU_LOGIN_ACCOUNT:-}"
login_pwd_md5="${FUTU_LOGIN_PWD_MD5:-}"

if [ -z "$login_account" ]; then
  read -r -p "Futu login account: " login_account
fi

if [ -z "$login_pwd_md5" ]; then
  read -r -s -p "Futu login password: " login_password
  echo
  login_pwd_md5="$(printf '%s' "$login_password" | md5sum | awk '{print $1}')"
  unset login_password
fi

if ! printf '%s' "$login_pwd_md5" | grep -Eq '^[0-9a-fA-F]{32}$'; then
  echo "FUTU_LOGIN_PWD_MD5 must be a 32-character hex MD5 value." >&2
  exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  SUDO="sudo"
fi

$SUDO env \
  CONFIG_FILE="$CONFIG_FILE" \
  FUTU_LOGIN_ACCOUNT="$login_account" \
  FUTU_LOGIN_PWD_MD5="$(printf '%s' "$login_pwd_md5" | tr 'A-F' 'a-f')" \
  API_IP="$API_IP" \
  API_PORT="$API_PORT" \
  python3 - <<'PY'
import html
import os
import re
from pathlib import Path

path = Path(os.environ["CONFIG_FILE"])
text = path.read_text(encoding="utf-8", errors="ignore")


def set_tag(source: str, tag: str, value: str) -> str:
    escaped = html.escape(value, quote=False)
    replacement = f"<{tag}>{escaped}</{tag}>"
    pattern = rf"<!--\s*<{tag}>.*?</{tag}>\s*-->|<{tag}>.*?</{tag}>"
    if re.search(pattern, source, flags=re.S):
        return re.sub(pattern, replacement, source, count=1, flags=re.S)
    return source


text = set_tag(text, "ip", os.environ["API_IP"])
text = set_tag(text, "api_port", os.environ["API_PORT"])
text = set_tag(text, "login_account", os.environ["FUTU_LOGIN_ACCOUNT"])
text = set_tag(text, "login_pwd_md5", os.environ["FUTU_LOGIN_PWD_MD5"])
text = set_tag(text, "login_pwd", "")

path.write_text(text, encoding="utf-8")
PY

$SUDO chown root:ubuntu "$CONFIG_FILE" || true
$SUDO chmod 640 "$CONFIG_FILE"

echo "FutuOpenD login config updated: $CONFIG_FILE"
echo "Plaintext password was not written to the config file."
