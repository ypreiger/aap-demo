#!/usr/bin/env bash
# Idempotent: ensure Job setting AWX_COLLECTIONS_ENABLED is true, create a public
# Galaxy API Token credential (if missing), and attach it to an organization’s
# galaxy_credentials list. Requires curl + jq.
#
# Usage:
#   export CONTROLLER_HOST="https://automation-controller-.../api"
#   export CONTROLLER_TOKEN="<OAuth2 token from Controller Application or user token>"
#   Optional: ORG_NAME=Default CRED_NAME="Galaxy (ansible.com)" GALAXY_URL="https://galaxy.ansible.com/"
#
# CONTROLLER_HOST should be the API root (often ends with /api) — same as Secret key "host" in aap-yamls.

set -euo pipefail

CONTROLLER_HOST="${CONTROLLER_HOST:-}"
CONTROLLER_TOKEN="${CONTROLLER_TOKEN:-}"
ORG_NAME="${ORG_NAME:-Default}"
CRED_NAME="${CRED_NAME:-Galaxy (ansible.com)}"
GALAXY_URL="${GALAXY_URL:-https://galaxy.ansible.com/}"
VERIFY_SSL="${VERIFY_SSL:-false}"

if [[ -z "$CONTROLLER_HOST" || -z "$CONTROLLER_TOKEN" ]]; then
  echo "Set CONTROLLER_HOST and CONTROLLER_TOKEN (see aap-yamls/secrets/aap-controller-api-secret.example.yaml)." >&2
  exit 1
fi

# Normalize: accept host with or without trailing /api
BASE="${CONTROLLER_HOST%/}"
if [[ "$BASE" != */api ]]; then
  BASE="${BASE}/api"
fi

curl_api() {
  local method="$1"
  local path="$2"
  local data="${3:-}"
  local args=(-sS -X "$method" -H "Authorization: Bearer ${CONTROLLER_TOKEN}" -H "Content-Type: application/json")
  if [[ "$VERIFY_SSL" != "true" ]]; then
    args+=(-k)
  fi
  if [[ -n "$data" ]]; then
    curl "${args[@]}" -d "$data" "${BASE}${path}"
  else
    curl "${args[@]}" "${BASE}${path}"
  fi
}

echo "==> Fetching /settings/jobs/ (AWX_COLLECTIONS_ENABLED)"
JOBS_SETTINGS=$(curl_api GET "/v2/settings/jobs/")
ENABLED=$(echo "$JOBS_SETTINGS" | jq -r '.AWX_COLLECTIONS_ENABLED // false')
if [[ "$ENABLED" != "true" ]]; then
  echo "    Patching AWX_COLLECTIONS_ENABLED -> true"
  MERGED=$(echo "$JOBS_SETTINGS" | jq -c '. + {"AWX_COLLECTIONS_ENABLED": true}')
  curl_api PATCH "/v2/settings/jobs/" "$MERGED" >/dev/null
  echo "    Done."
else
  echo "    Already enabled."
fi

echo "==> Resolving credential type: Ansible Galaxy/Automation Hub API Token"
CT=$(curl_api GET "/v2/credential_types/?search=Ansible+Galaxy")
CT_ID=$(echo "$CT" | jq -r '.results[] | select(.name == "Ansible Galaxy/Automation Hub API Token") | .id' | head -1)
if [[ -z "$CT_ID" || "$CT_ID" == "null" ]]; then
  echo "Could not find Galaxy credential type (unexpected Controller version?)." >&2
  exit 1
fi

echo "==> Resolving organization: ${ORG_NAME}"
ORG_JSON=$(curl_api GET "/v2/organizations/")
ORG_ID=$(echo "$ORG_JSON" | jq -r --arg n "$ORG_NAME" '[.results[]? | select(.name == $n) | .id][0] // empty')
if [[ -z "$ORG_ID" || "$ORG_ID" == "null" ]]; then
  echo "Organization '${ORG_NAME}' not found." >&2
  exit 1
fi

echo "==> Finding or creating credential: ${CRED_NAME}"
ENC_NAME=$(jq -rn --arg x "$CRED_NAME" '$x|@uri')
CRED_SEARCH=$(curl_api GET "/v2/credentials/?name=${ENC_NAME}&organization=${ORG_ID}")
CRED_ID=$(echo "$CRED_SEARCH" | jq -r '.results[0].id // empty')

INPUTS_JSON=$(jq -nc --arg url "$GALAXY_URL" '{url: $url, token: ""}')

if [[ -z "$CRED_ID" || "$CRED_ID" == "null" ]]; then
  BODY=$(jq -nc \
    --arg name "$CRED_NAME" \
    --argjson org "$ORG_ID" \
    --argjson ct "$CT_ID" \
    --argjson inputs "$INPUTS_JSON" \
    '{name: $name, description: "Public ansible.com Galaxy (collections for aap-demo)", organization: $org, credential_type: $ct, inputs: $inputs}')
  RESP=$(curl_api POST "/v2/credentials/" "$BODY")
  CRED_ID=$(echo "$RESP" | jq -r '.id // empty')
  if [[ -z "$CRED_ID" || "$CRED_ID" == "null" ]]; then
    echo "Failed to create credential: $RESP" >&2
    exit 1
  fi
  echo "    Created credential id=${CRED_ID}"
else
  echo "    Exists id=${CRED_ID}"
fi

echo "==> Attaching credential to organization galaxy_credentials (if missing)"
GC=$(curl_api GET "/v2/organizations/${ORG_ID}/galaxy_credentials/")
ALREADY=$(echo "$GC" | jq -r --argjson id "$CRED_ID" '([.results // [] | .[].id] | index($id)) != null')
if [[ "$ALREADY" == "true" ]]; then
  echo "    Already attached."
else
  curl_api POST "/v2/organizations/${ORG_ID}/galaxy_credentials/" "$(jq -nc --argjson id "$CRED_ID" '{id: $id}')" >/dev/null
  echo "    Attached."
fi

echo "==> Done. In Controller: Projects → sync your SCM project and check the Project Update output for collection install."
