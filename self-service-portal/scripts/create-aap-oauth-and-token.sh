#!/usr/bin/env bash
# Optional helper: create Gateway OAuth app + personal token via in-cluster API (admin password required).
# Prints export statements for bootstrap-secrets.sh — does not print secrets to git.
set -euo pipefail

NAMESPACE="${NAMESPACE:-aap}"
RELEASE_NAME="${RELEASE_NAME:-aap-portal}"
APPS_DOMAIN="${APPS_DOMAIN:-}"
APP_NAME="${APP_NAME:-aap-self-service-portal}"

[[ -n "$APPS_DOMAIN" ]] || APPS_DOMAIN="$(oc get ingresscontroller cluster -o jsonpath='{.status.domain}')"
REDIRECT="https://${RELEASE_NAME}-rhaap-portal-${NAMESPACE}.${APPS_DOMAIN}/api/auth/rhaap/handler/frame"
GW_URL="$(oc get route demo-aap -n "$NAMESPACE" -o jsonpath='https://{.spec.host}')"
PASS="$(oc get secret demo-aap-admin-password -n "$NAMESPACE" -o jsonpath='{.data.password}' | base64 -d)"

GW_POD="$(oc get pod -n "$NAMESPACE" -o name | grep 'demo-aap-gateway' | grep -v Terminating | head -1 | sed 's|pod/||')"
[[ -n "$GW_POD" ]] || { echo "No running gateway pod"; exit 1; }

api() {
  oc exec -n "$NAMESPACE" "$GW_POD" -c api -- \
    curl -sk -u "admin:${PASS}" "http://127.0.0.1:8000$1" "${@:2}"
}

# Enable external OAuth tokens (required for portal sign-in)
api /api/gateway/v1/settings/oauth2_provider/ -X PUT \
  -H 'Content-Type: application/json' \
  -d '{"ALLOW_OAUTH2_FOR_EXTERNAL_USERS": true}' >/dev/null

APP_JSON="$(api /api/gateway/v1/applications/ -X POST -H 'Content-Type: application/json' -d "{
  \"name\": \"${APP_NAME}\",
  \"description\": \"Ansible automation portal GitOps\",
  \"organization\": 1,
  \"authorization_grant_type\": \"authorization-code\",
  \"client_type\": \"confidential\",
  \"redirect_uris\": \"${REDIRECT}\",
  \"skip_authorization\": false
}")"

TOKEN_JSON="$(api /api/gateway/v1/tokens/ -X POST -H 'Content-Type: application/json' -d '{
  "description": "aap-portal-catalog",
  "user": 2,
  "scope": "read"
}')"

python3 - <<PY "$APP_JSON" "$TOKEN_JSON" "$GW_URL"
import json, sys
app, tok, gw = json.loads(sys.argv[1]), json.loads(sys.argv[2]), sys.argv[3]
print(f"export AAP_HOST_URL={gw!r}")
print(f"export OAUTH_CLIENT_ID={app['client_id']!r}")
print(f"export OAUTH_CLIENT_SECRET={app['client_secret']!r}")
print(f"export AAP_TOKEN={tok['token']!r}")
PY

echo "# Run: eval \"\$(./scripts/create-aap-oauth-and-token.sh)\" && ./scripts/bootstrap-secrets.sh"
