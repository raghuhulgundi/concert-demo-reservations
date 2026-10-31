#!/usr/bin/env bash
# Deploy, or update, the reservation board on Red Hat OpenShift.
#
# Run from the repo folder on your Mac or Linux machine, after logging in:
#   oc login --token=... --server=...      (copy it from the console: your name > Copy login command)
#   ./deploy/openshift/deploy.sh
#
# Safe to run again any time: after editing config.openshift.json, or after a git pull.
# Optional: PROJECT=my-project ROUTE_HOST=reserve.example.com ./deploy/openshift/deploy.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

PROJECT="${PROJECT:-demo-reservations}"
APP="demo-reserve"
CONFIG_FILE="${CONFIG_FILE:-config.openshift.json}"
ROUTE_HOST="${ROUTE_HOST:-}"

say()  { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

command -v oc >/dev/null 2>&1      || die "The OpenShift CLI (oc) isn't installed."
command -v python3 >/dev/null 2>&1 || die "python3 is needed"
[ -f server.py ] || die "Run this from the repo folder"

say "Checking your OpenShift login"
oc whoami >/dev/null 2>&1 || die "Not logged in. In the OpenShift console click your name > Copy login command, run it, then run this script again."
info "$(oc whoami) on $(oc whoami --show-server)"

say "Project: $PROJECT"
if oc get project "$PROJECT" >/dev/null 2>&1; then
  oc project "$PROJECT" -q >/dev/null
  info "Using existing project"
else
  oc new-project "$PROJECT" --display-name="Concert Operate demo reservations" >/dev/null
  info "Created"
fi

# ------------------------------------------------------------------ settings
if [ ! -f "$CONFIG_FILE" ]; then
  python3 - "$CONFIG_FILE" <<'PYEOF'
import json, secrets, sys
cfg = json.load(open("config.example.json"))
cfg.update(host="0.0.0.0", port=8080, tls=False)          # the Route handles HTTPS
for k in ("tls_cert", "tls_key", "tls_extra_names"):
    cfg.pop(k, None)
cfg["admin_key"] = secrets.token_hex(24)
cfg.setdefault("auth", {})["redirect_uri"] = ""
with open(sys.argv[1], "w") as fh:
    json.dump(cfg, fh, indent=2)
    fh.write("\n")
PYEOF
  chmod 600 "$CONFIG_FILE"
  info "Created $CONFIG_FILE (sign-in off, random admin key). Edit it later and run this script again."
fi
python3 -c 'import json,sys; c=json.load(open(sys.argv[1])); assert not c.get("tls"), "set \"tls\": false (the Route does HTTPS)"' "$CONFIG_FILE" \
  || die "$CONFIG_FILE isn't valid JSON, or has \"tls\": true. The Route handles HTTPS, so the app must use \"tls\": false."

say "Storing settings in Secret $APP-config"
oc create secret generic "$APP-config" --from-file=config.json="$CONFIG_FILE" --dry-run=client -o yaml | oc apply -f - >/dev/null
CONFIG_HASH="$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest()[:16])' "$CONFIG_FILE")"

# ------------------------------------------------------------------ resources
say "Applying build, storage, service and route"
oc apply -f deploy/openshift/openshift.yaml >/dev/null
if [ -n "$ROUTE_HOST" ]; then
  oc patch route "$APP" --type=merge -p "{\"spec\":{\"host\":\"$ROUTE_HOST\"}}" >/dev/null
  info "Route host set to $ROUTE_HOST"
fi
if ! oc get deployment "$APP" >/dev/null 2>&1; then
  oc apply -f deploy/openshift/deployment.yaml >/dev/null
  info "Created the Deployment"
fi
# A changed settings file restarts the app (it reads settings at startup).
oc patch deployment "$APP" --type=merge -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"demo-reserve/config-hash\":\"$CONFIG_HASH\"}}}}}" >/dev/null

# ------------------------------------------------------------------ build
say "Building the image in the cluster (1 to 3 minutes)"
CTX="$(mktemp -d)"
trap 'rm -rf "$CTX"' EXIT
mkdir -p "$CTX/deploy/openshift"
cp server.py VERSION "$CTX/"
cp -R static "$CTX/static"
cp deploy/openshift/Containerfile "$CTX/deploy/openshift/"
# Only the app files are uploaded: never your settings file, data or .git
oc start-build "$APP" --from-dir="$CTX" --follow --wait
sleep 5   # give the image trigger a moment to start the rollout

say "Waiting for the new version to start"
oc rollout status deployment/"$APP" --timeout=300s

HOST="$(oc get route "$APP" -o jsonpath='{.spec.host}')"
URL="https://$HOST"
HEALTH="$(curl -s --max-time 20 "$URL/healthz" || true)"
info "Health: ${HEALTH:-no answer yet, try the URL in a minute}"

AUTH_ON="$(python3 -c 'import json,sys; print(str(json.load(open(sys.argv[1])).get("auth",{}).get("enabled",False)).lower())' "$CONFIG_FILE")"
REDIRECT="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("auth",{}).get("redirect_uri",""))' "$CONFIG_FILE")"
printf '\n======================================================================\n'
printf ' Reservation board is running on OpenShift.\n\n'
printf ' URL:  %s\n\n' "$URL"
printf ' IBMid redirect URL to register in the SSO tool:\n   %s/auth/callback\n' "$URL"
if [ "$AUTH_ON" = "true" ] && [ "$REDIRECT" != "$URL/auth/callback" ]; then
  printf '\n WARNING: auth.redirect_uri in %s is "%s".\n' "$CONFIG_FILE" "$REDIRECT"
  printf '          Set it to %s/auth/callback and run this script again.\n' "$URL"
fi
[ "$AUTH_ON" = "true" ] || printf '\n IBMid sign-in is OFF. Fill in the auth section of %s and run this script again.\n' "$CONFIG_FILE"
printf '\n Logs:     oc logs -f deployment/%s -n %s\n' "$APP" "$PROJECT"
printf ' Restart:  oc rollout restart deployment/%s -n %s\n' "$APP" "$PROJECT"
printf '======================================================================\n'
