#!/usr/bin/env bash
# Install or update the Concert Operate demo reservation board on a RHEL 8/9 VM.
#
# Run from the repo folder:
#   sudo ./deploy/install-rhel.sh
#
# Safe to run again at any time (after editing config.json or after a git pull):
# it never overwrites your config.json, reservations, partner list or certificate.
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE="demo-reserve"
UNIT="/etc/systemd/system/${SERVICE}.service"
CONFIG="${APP_DIR}/config.json"

say()  { printf '\n==> %s\n' "$*"; }
warn() { printf '    WARNING: %s\n' "$*"; }
die()  { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Run this with sudo:  sudo $0"
[ -f "${APP_DIR}/server.py" ] || die "server.py not found in ${APP_DIR}. Run the script from inside the cloned repo."

# ------------------------------------------------------------------ packages
say "Checking required packages (python3, openssl, git, curl)"
need=()
for cmd in python3 openssl git curl; do
  command -v "$cmd" >/dev/null 2>&1 || need+=("$cmd")
done
if [ "${#need[@]}" -gt 0 ]; then
  command -v dnf >/dev/null 2>&1 || die "Missing: ${need[*]} (and dnf isn't available to install them)"
  echo "    Installing: ${need[*]}"
  dnf install -y "${need[@]}"
fi
PY="$(command -v python3)"
"$PY" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 6) else 1)' || die "Python 3.6 or newer is required"
echo "    $("$PY" --version 2>&1), $(openssl version | cut -d' ' -f1-2)"

# ------------------------------------------------------------------ addresses
say "Finding this VM's addresses"
PUBLIC_IP="$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || true)"
[[ "$PUBLIC_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || PUBLIC_IP=""
PRIVATE_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
FQDN="$(hostname -f 2>/dev/null || hostname)"
echo "    Hostname:   ${FQDN:-unknown}"
echo "    Private IP: ${PRIVATE_IP:-unknown}"
echo "    Public IP:  ${PUBLIC_IP:-not detected}"

# ------------------------------------------------------------------ config
NEW_CONFIG=0
if [ ! -f "$CONFIG" ]; then
  say "Creating config.json from config.example.json"
  cp "${APP_DIR}/config.example.json" "$CONFIG"
  "$PY" - "$CONFIG" "$PUBLIC_IP" "$PRIVATE_IP" "$FQDN" <<'PYEOF'
import json, secrets, sys
path = sys.argv[1]
names = [n for n in sys.argv[2:] if n]
with open(path) as fh:
    cfg = json.load(fh)
cfg["admin_key"] = secrets.token_hex(24)
cfg["tls_extra_names"] = list(dict.fromkeys(names))
with open(path, "w") as fh:
    json.dump(cfg, fh, indent=2)
    fh.write("\n")
PYEOF
  NEW_CONFIG=1
  echo "    Generated a random admin_key and added this VM's names to the certificate list."
else
  echo "    Using existing config.json (not changed)"
fi
chmod 600 "$CONFIG"

"$PY" -c 'import json,sys; json.load(open(sys.argv[1]))' "$CONFIG" 2>/dev/null \
  || die "config.json isn't valid JSON. Check for a missing comma or quote, then run this script again."
PORT="$("$PY" -c 'import json,sys; print(json.load(open(sys.argv[1])).get("port", 443))' "$CONFIG")"
AUTH_ON="$("$PY" -c 'import json,sys; print(str(json.load(open(sys.argv[1])).get("auth", {}).get("enabled", False)).lower())' "$CONFIG")"

grep -q 'REPLACE-with-robin\|REPLACE-with-yoda' "$CONFIG" \
  && warn "The Robin/Yoda console URLs are still placeholders in config.json, so the Open buttons will be greyed out."

# ------------------------------------------------------------------ port check
if command -v ss >/dev/null 2>&1; then
  holder="$(ss -ltnpH "sport = :${PORT}" 2>/dev/null | grep -v "$SERVICE" | head -1 || true)"
  if [ -n "$holder" ] && ! systemctl is-active --quiet "$SERVICE"; then
    die "Port ${PORT} is already used by another program:
    ${holder}
Stop it first (for example: sudo systemctl disable --now httpd nginx), then run this script again."
  fi
fi

# ------------------------------------------------------------------ firewall
say "Opening port ${PORT} in the firewall"
if systemctl is-active --quiet firewalld 2>/dev/null; then
  if [ "$PORT" = "443" ]; then
    firewall-cmd --quiet --permanent --add-service=https
  else
    firewall-cmd --quiet --permanent --add-port="${PORT}/tcp"
  fi
  firewall-cmd --quiet --reload
  echo "    firewalld updated"
else
  echo "    firewalld isn't running, nothing to do"
fi

# ------------------------------------------------------------------ SELinux
if command -v restorecon >/dev/null 2>&1; then
  restorecon -R "$APP_DIR" >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------ systemd
say "Installing the ${SERVICE} service"
cat > "$UNIT" <<EOF
[Unit]
Description=Concert Operate demo environment reservation board
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${APP_DIR}
ExecStart=${PY} ${APP_DIR}/server.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --quiet "$SERVICE"
systemctl restart "$SERVICE"

# ------------------------------------------------------------------ health check
say "Waiting for the app to start"
ok=0
for _ in $(seq 1 20); do
  if curl -sk --max-time 2 "https://127.0.0.1:${PORT}/healthz" 2>/dev/null | grep -q '"ok": true'; then ok=1; break; fi
  if curl -s  --max-time 2 "http://127.0.0.1:${PORT}/healthz"  2>/dev/null | grep -q '"ok": true'; then ok=1; break; fi
  sleep 1
done
if [ "$ok" != 1 ]; then
  echo
  journalctl -u "$SERVICE" -n 25 --no-pager || true
  die "The app didn't start. The log above usually says why (for example a sign-in setting left empty)."
fi
VERSION="$(curl -sk --max-time 2 "https://127.0.0.1:${PORT}/healthz" | "$PY" -c 'import json,sys; print(json.load(sys.stdin).get("version","?"))' 2>/dev/null || echo '?')"

# ------------------------------------------------------------------ summary
HOST="${PUBLIC_IP:-${FQDN:-$PRIVATE_IP}}"
SUFFIX=""; [ "$PORT" = "443" ] || SUFFIX=":${PORT}"
printf '\n======================================================================\n'
printf ' Reservation board v%s is running.\n\n' "$VERSION"
printf ' Open:  https://%s%s\n' "$HOST" "$SUFFIX"
[ -n "$PUBLIC_IP" ] && [ -n "$FQDN" ] && printf '   or:  https://%s%s  (if that hostname resolves for your users)\n' "$FQDN" "$SUFFIX"
printf '\n Your browser will warn about the self-signed certificate the first time:\n'
printf ' click Advanced, then Proceed.\n'
if [ "$AUTH_ON" != "true" ]; then
  printf '\n IBMid sign-in is OFF. Anyone who can reach the URL can book.\n'
  printf ' To turn it on, see README section 4, then run this script again.\n'
fi
if [ "$NEW_CONFIG" = 1 ]; then
  printf '\n Next: edit %s\n' "$CONFIG"
  printf '   - Robin and Yoda console URLs\n'
  printf '   - admin_emails (your IBMid email) and the auth section\n'
  printf ' then run:  sudo %s\n' "$0"
fi
printf '\n Logs:     sudo journalctl -u %s -f\n' "$SERVICE"
printf ' Restart:  sudo systemctl restart %s\n' "$SERVICE"
printf '======================================================================\n'
