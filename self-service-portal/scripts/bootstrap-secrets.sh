#!/usr/bin/env bash
# Create required secrets in namespace aap before Argo CD syncs the portal Helm release.
set -euo pipefail

NAMESPACE="${NAMESPACE:-aap}"
RELEASE_NAME="${RELEASE_NAME:-aap-portal}"
AAP_HOST_URL="${AAP_HOST_URL:-}"
OAUTH_CLIENT_ID="${OAUTH_CLIENT_ID:-}"
OAUTH_CLIENT_SECRET="${OAUTH_CLIENT_SECRET:-}"
AAP_TOKEN="${AAP_TOKEN:-}"
REGISTRY_AUTH_SECRET="${RELEASE_NAME}-dynamic-plugins-registry-auth"

log() { printf '[bootstrap-secrets] %s\n' "$*"; }
die() { log "ERROR: $*"; exit 1; }

command -v oc >/dev/null || die "oc not found"
oc project "$NAMESPACE" >/dev/null 2>&1 || oc project "$NAMESPACE" || die "cannot use namespace $NAMESPACE"

if [[ -z "$AAP_HOST_URL" ]]; then
  AAP_HOST_URL="$(oc get route demo-aap -n "$NAMESPACE" -o jsonpath='https://{.spec.host}' 2>/dev/null || true)"
fi
[[ -n "$AAP_HOST_URL" ]] || die "Set AAP_HOST_URL (gateway URL, e.g. https://demo-aap-aap.apps.<cluster>)"

# --- registry.redhat.io auth for OCI dynamic plugins (required for pluginMode: oci) ---
if ! oc get secret "$REGISTRY_AUTH_SECRET" -n "$NAMESPACE" >/dev/null 2>&1; then
  log "Creating $REGISTRY_AUTH_SECRET from cluster pull-secret (registry.redhat.io)"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  oc get secret pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d >"$tmp/.dockerconfigjson"
  python3 - <<'PY' "$tmp/.dockerconfigjson" "$tmp/auth.json"
import json, sys
src, dst = sys.argv[1], sys.argv[2]
with open(src) as f:
    cfg = json.load(f)
auths = cfg.get("auths", {})
redhat = auths.get("registry.redhat.io") or auths.get("registry.connect.redhat.com")
if not redhat:
    sys.exit("registry.redhat.io not in cluster pull-secret")
out = {"auths": {"registry.redhat.io": redhat}}
with open(dst, "w") as f:
    json.dump(out, f)
PY
  oc create secret generic "$REGISTRY_AUTH_SECRET" \
    --from-file=auth.json="$tmp/auth.json" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | oc apply -f -
else
  log "Secret $REGISTRY_AUTH_SECRET already exists — skipping"
fi

# --- AAP OAuth + catalog token ---
if [[ -z "$OAUTH_CLIENT_ID" || -z "$OAUTH_CLIENT_SECRET" || -z "$AAP_TOKEN" ]]; then
  cat <<EOF

Required environment variables for secrets-rhaap-portal:
  OAUTH_CLIENT_ID       OAuth app client ID (Gateway → Applications)
  OAUTH_CLIENT_SECRET   OAuth app client secret
  AAP_TOKEN             Gateway personal access token (read scope minimum; write for templates)

Create an OAuth application in AAP (Platform gateway) with redirect URI:
  https://${RELEASE_NAME}-rhaap-portal-${NAMESPACE}.<your-apps-domain>/api/auth/rhaap/handler/frame

Enable: Settings → Platform gateway → Allow external users to create OAuth2 tokens

Then re-run:
  export OAUTH_CLIENT_ID=... OAUTH_CLIENT_SECRET=... AAP_TOKEN=...
  $0

EOF
  die "Missing OAUTH_CLIENT_ID, OAUTH_CLIENT_SECRET, or AAP_TOKEN"
fi

oc create secret generic secrets-rhaap-portal \
  --from-literal=aap-host-url="$AAP_HOST_URL" \
  --from-literal=oauth-client-id="$OAUTH_CLIENT_ID" \
  --from-literal=oauth-client-secret="$OAUTH_CLIENT_SECRET" \
  --from-literal=aap-token="$AAP_TOKEN" \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml | oc apply -f -

log "secrets-rhaap-portal and $REGISTRY_AUTH_SECRET are ready in namespace $NAMESPACE"
