#!/usr/bin/env bash
# Idempotent: set the Automation Hub "community" collection remote requirements_file
# from this repo's collections/requirements.yml, then trigger a community repository sync.
#
# Why: Galaxy NG / Pulp on AAP may reject syncing galaxy.ansible.com without a
# requirements_file — the Hub UI can show an empty collections list until community
# content exists. See documentation/HUB_COLLECTIONS.md.
#
# Prerequisites: oc (logged in), curl, jq; Hub admin password in OpenShift Secret.
#
# Usage (from repo root):
#   export HUB_GATEWAY_URL="https://<aap-gateway-host>"   # e.g. demo-aap-aap.apps....
#   ./scripts/hub-sync-community-from-requirements.sh
#
# Optional:
#   HUB_NAMESPACE=aap HUB_ADMIN_SECRET=demo-aap-hub-admin-password
#   HUB_ADMIN_USER=admin
#   REQUIREMENTS_FILE=collections/requirements.yml
#   SYNC_MIRROR=false          # POST body mirror flag (default false)
#   WAIT_FOR_SYNC=true         # poll Pulp task until completed|failed|canceled
#   CURL_EXTRA="-k"            # if your TLS needs -k (default -k)
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

for x in curl jq oc; do
  command -v "$x" >/dev/null || {
    echo "Missing dependency: ${x}" >&2
    exit 1
  }
done

HUB_GATEWAY_URL="${HUB_GATEWAY_URL:-}"
HUB_NAMESPACE="${HUB_NAMESPACE:-aap}"
HUB_ADMIN_SECRET="${HUB_ADMIN_SECRET:-demo-aap-hub-admin-password}"
HUB_ADMIN_USER="${HUB_ADMIN_USER:-admin}"
REQUIREMENTS_FILE="${REQUIREMENTS_FILE:-collections/requirements.yml}"
SYNC_MIRROR="${SYNC_MIRROR:-false}"
WAIT_FOR_SYNC="${WAIT_FOR_SYNC:-true}"
CURL_EXTRA="${CURL_EXTRA:--k}"

if [[ -z "$HUB_GATEWAY_URL" ]]; then
  echo "Set HUB_GATEWAY_URL to the AAP gateway base (same host you use for / content / hub UI), e.g.:" >&2
  echo "  export HUB_GATEWAY_URL=\"https://demo-aap-aap.apps.<cluster>/\"" >&2
  exit 1
fi

HUB_GATEWAY_URL="${HUB_GATEWAY_URL%/}"
REQ_PATH="${ROOT}/${REQUIREMENTS_FILE}"
if [[ ! -f "$REQ_PATH" ]]; then
  echo "requirements file not found: ${REQ_PATH}" >&2
  exit 1
fi

PASSWORD="$(oc get secret -n "${HUB_NAMESPACE}" "${HUB_ADMIN_SECRET}" -o jsonpath='{.data.password}' | base64 -d)"
if [[ -z "$PASSWORD" ]]; then
  echo "Could not read password from Secret ${HUB_ADMIN_SECRET} in ns ${HUB_NAMESPACE}" >&2
  exit 1
fi

AUTH=( -u "${HUB_ADMIN_USER}:${PASSWORD}" )

curl_hub() {
  local method="$1"
  local path="$2"
  local data="${3:-}"
  local opts=( -sS "${AUTH[@]}" -X "${method}" -H "Content-Type: application/json" )
  # shellcheck disable=SC2206
  opts+=( ${CURL_EXTRA} )
  if [[ -n "${data}" ]]; then
    curl "${opts[@]}" -d "${data}" "${HUB_GATEWAY_URL}${path}"
  else
    curl "${opts[@]}" "${HUB_GATEWAY_URL}${path}"
  fi
}

echo "==> Resolving Pulp remote name=community"
REMOTES_JSON="$(curl_hub GET "/api/galaxy/pulp/api/v3/remotes/ansible/collection/?name=community")"
REMOTE_HREF="$(echo "$REMOTES_JSON" | jq -r '.results[0].pulp_href // empty')"
if [[ -z "$REMOTE_HREF" || "$REMOTE_HREF" == "null" ]]; then
  echo "Could not find collection remote named 'community'. Raw: ${REMOTES_JSON}" >&2
  exit 1
fi

echo "==> Resolving ansible repository name=community"
REPOS_JSON="$(curl_hub GET "/api/galaxy/pulp/api/v3/repositories/ansible/ansible/?name=community")"
REPO_HREF="$(echo "$REPOS_JSON" | jq -r '.results[0].pulp_href // empty')"
if [[ -z "$REPO_HREF" || "$REPO_HREF" == "null" ]]; then
  echo "Could not find ansible repository named 'community'." >&2
  exit 1
fi

BODY_PATCH="$(jq -n --arg rf "$(cat "${REQ_PATH}")" '{requirements_file: $rf}')"

echo "==> PATCH ${REMOTE_HREF} (requirements_file from ${REQUIREMENTS_FILE})"
curl_hub PATCH "${REMOTE_HREF}" "${BODY_PATCH}" >/dev/null

if [[ "${SYNC_MIRROR}" == "true" ]]; then
  _mirror_json="true"
else
  _mirror_json="false"
fi
SYNC_PAYLOAD="$(jq -n --arg r "$REMOTE_HREF" --argjson m "${_mirror_json}" '{remote: $r, mirror: $m}')"
SYNC_UP="${REPO_HREF%/}/sync/"

echo "==> POST ${SYNC_UP}"
SYNC_RESP="$(curl_hub POST "${SYNC_UP}" "${SYNC_PAYLOAD}")"
TASK_HREF="$(echo "$SYNC_RESP" | jq -r '
  if (.task | type) == "string" then .task
  elif (.task | type) == "object" and (.task.pulp_href != null) then .task.pulp_href
  else empty end
' 2>/dev/null || true)"
if [[ -z "$TASK_HREF" || "$TASK_HREF" == "null" ]]; then
  echo "Sync response (unexpected shape): ${SYNC_RESP}" >&2
  exit 1
fi
if [[ "${TASK_HREF}" != http://* && "${TASK_HREF}" != https://* ]]; then
  TASK_HREF="${HUB_GATEWAY_URL%/}${TASK_HREF}"
fi

echo "    task: ${TASK_HREF}"

if [[ "$WAIT_FOR_SYNC" != "true" ]]; then
  echo "WAIT_FOR_SYNC!=true — not polling. Check task in Hub UI or GET ${TASK_HREF}"
  exit 0
fi

echo "==> Waiting for task to finish (poll every 10s, max ~60m)"
deadline=$((SECONDS + 3600))
while (( SECONDS < deadline )); do
  TJSON="$(curl_hub GET "${TASK_HREF}")"
  STATE="$(echo "$TJSON" | jq -r '.state // empty')"
  case "$STATE" in
    completed)
      echo "    state=${STATE}"
      echo "OK — community repository sync finished."
      echo "Verify: GET ${HUB_GATEWAY_URL}/api/galaxy/v3/plugin/ansible/content/community/collections/index/?limit=1"
      exit 0
      ;;
    failed|canceled)
      echo "Task ended with state=${STATE}" >&2
      echo "$TJSON" | jq . >&2
      exit 1
      ;;
    *)
      printf '    ... %s\r' "${STATE}"
      sleep 10
      ;;
  esac
done

echo "Timed out waiting for ${TASK_HREF}" >&2
exit 1
