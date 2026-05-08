#!/usr/bin/env bash
# Populate the Hub "published" Ansible repository so the gateway Collections UI
# (paths like /api/galaxy/v3/plugin/ansible/content/published/) shows Red Hat
# certified content. Certified sync normally fills repository "rh-certified"
# only; repository "published" starts with remote=null and stays empty unless
# mirrored here.
#
# Prerequisites: oc, curl, jq; Hub admin password in demo-aap-hub-admin-password.
#
# Usage:
#   export HUB_GATEWAY_URL="https://<aap-gateway-host>"
#   ./scripts/hub-sync-published-mirror-rh-certified.sh
#
# Optional: WAIT_FOR_SYNC=false to start sync and exit without polling.
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

HUB_GATEWAY_URL="${HUB_GATEWAY_URL%/}"
HUB_NAMESPACE="${HUB_NAMESPACE:-aap}"
HUB_ADMIN_SECRET="${HUB_ADMIN_SECRET:-demo-aap-hub-admin-password}"
WAIT_FOR_SYNC="${WAIT_FOR_SYNC:-true}"
CURL_EXTRA="${CURL_EXTRA:--k}"

if [[ -z "${HUB_GATEWAY_URL}" ]]; then
  echo "Set HUB_GATEWAY_URL to the AAP gateway base URL." >&2
  exit 1
fi

PASSWORD="$(oc get secret -n "${HUB_NAMESPACE}" "${HUB_ADMIN_SECRET}" -o jsonpath='{.data.password}' | base64 -d)"
AUTH=( -u "admin:${PASSWORD}" )

curl_hub() {
  local method="$1"
  local path="$2"
  local data="${3:-}"
  local url
  if [[ "${path}" == http://* || "${path}" == https://* ]]; then
    url="${path}"
  else
    url="${HUB_GATEWAY_URL}${path}"
  fi
  local opts=( -sS "${AUTH[@]}" -X "${method}" -H "Content-Type: application/json" )
  # shellcheck disable=SC2206
  opts+=( ${CURL_EXTRA} )
  if [[ -n "${data}" ]]; then
    curl "${opts[@]}" -d "${data}" "${url}"
  else
    curl "${opts[@]}" "${url}"
  fi
}

echo "==> Resolve rh-certified collection remote"
REMOTES_JSON="$(curl_hub GET "/api/galaxy/pulp/api/v3/remotes/ansible/collection/?name=rh-certified")"
REMOTE_HREF="$(echo "${REMOTES_JSON}" | jq -r '.results[0].pulp_href // empty')"
if [[ -z "${REMOTE_HREF}" || "${REMOTE_HREF}" == "null" ]]; then
  echo "Could not find remote named rh-certified." >&2
  exit 1
fi

echo "==> Resolve published ansible repository"
REPOS_JSON="$(curl_hub GET "/api/galaxy/pulp/api/v3/repositories/ansible/ansible/?name=published")"
REPO_HREF="$(echo "${REPOS_JSON}" | jq -r '.results[0].pulp_href // empty')"
CURRENT_REMOTE="$(echo "${REPOS_JSON}" | jq -r '.results[0].remote // empty')"
if [[ -z "${REPO_HREF}" || "${REPO_HREF}" == "null" ]]; then
  echo "Could not find repository named published." >&2
  exit 1
fi

if [[ "${CURRENT_REMOTE}" != "${REMOTE_HREF}" ]]; then
  echo "==> PATCH published repository remote → rh-certified remote"
  BODY="$(jq -n --arg r "${REMOTE_HREF}" '{remote: $r}')"
  curl_hub PATCH "${REPO_HREF}" "${BODY}" >/dev/null
else
  echo "    published repository already references rh-certified remote"
fi

SYNC_UP="${REPO_HREF%/}/sync/"
BODY_SYNC="$(jq -n --arg r "${REMOTE_HREF}" '{remote: $r, mirror: false}')"
echo "==> POST ${SYNC_UP}"
SYNC_RESP="$(curl_hub POST "${SYNC_UP}" "${BODY_SYNC}")"
TASK_HREF="$(echo "${SYNC_RESP}" | jq -r '
  if (.task | type) == "string" then .task
  elif (.task | type) == "object" and (.task.pulp_href != null) then .task.pulp_href
  else empty end
')"
if [[ -z "${TASK_HREF}" || "${TASK_HREF}" == "null" ]]; then
  echo "Unexpected sync response: ${SYNC_RESP}" >&2
  exit 1
fi
[[ "${TASK_HREF}" == http* ]] || TASK_HREF="${HUB_GATEWAY_URL}${TASK_HREF}"
echo "    task: ${TASK_HREF}"

if [[ "${WAIT_FOR_SYNC}" != "true" ]]; then
  exit 0
fi

echo "==> Waiting for sync (poll every 15s, max ~2h)"
deadline=$((SECONDS + 7200))
while (( SECONDS < deadline )); do
  TJSON="$(curl_hub GET "${TASK_HREF}")"
  STATE="$(echo "${TJSON}" | jq -r '.state // empty')"
  case "${STATE}" in
    completed)
      echo "OK — published repository sync finished."
      curl -sk "${AUTH[@]}" \
        "${HUB_GATEWAY_URL}/api/galaxy/v3/plugin/ansible/content/published/collections/index/?limit=1" \
        | jq '.meta'
      exit 0
      ;;
    failed|canceled)
      echo "${TJSON}" | jq . >&2
      exit 1
      ;;
    *)
      printf '    ... %s\r' "${STATE}"
      sleep 15
      ;;
  esac
done
echo "Timed out waiting for sync task." >&2
exit 1
