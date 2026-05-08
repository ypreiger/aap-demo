#!/usr/bin/env bash
# Apply Red Hat offline token from OpenShift Secret to Hub remote "rh-certified",
# then start repository sync for "rh-certified" (certified → Hub inventory).
#
# Prerequisites: oc, curl, jq; Hub admin password in demo-aap-hub-admin-password.
#
# Create/update secret first:
#   oc create secret generic rh-hub-offline-token -n aap \
#     --from-literal=token="$(cat ~/.offline_token)" --dry-run=client -o yaml | oc apply -f -
#
# Usage:
#   export HUB_GATEWAY_URL="https://<aap-gateway-host>"
#   ./scripts/hub-sync-rh-certified-from-secret.sh
#
# Optional: WAIT_FOR_SYNC=false to fire sync and exit without polling.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

for x in curl jq oc; do
  command -v "$x" >/dev/null || { echo "Missing: ${x}" >&2; exit 1; }
done

HUB_GATEWAY_URL="${HUB_GATEWAY_URL%/}"
HUB_NAMESPACE="${HUB_NAMESPACE:-aap}"
HUB_ADMIN_SECRET="${HUB_ADMIN_SECRET:-demo-aap-hub-admin-password}"
TOKEN_SECRET="${TOKEN_SECRET:-rh-hub-offline-token}"
TOKEN_KEY="${TOKEN_KEY:-token}"
WAIT_FOR_SYNC="${WAIT_FOR_SYNC:-true}"
CURL_EXTRA="${CURL_EXTRA:--k}"

if [[ -z "${HUB_GATEWAY_URL}" ]]; then
  echo "Set HUB_GATEWAY_URL (e.g. https://demo-aap-aap.apps.<cluster>/)" >&2
  exit 1
fi

PASSWORD="$(oc get secret -n "${HUB_NAMESPACE}" "${HUB_ADMIN_SECRET}" -o jsonpath='{.data.password}' | base64 -d)"
OFFLINE="$(oc get secret -n "${HUB_NAMESPACE}" "${TOKEN_SECRET}" -o jsonpath="{.data.${TOKEN_KEY}}" | base64 -d)"
if [[ -z "${OFFLINE}" ]]; then
  echo "Could not read ${TOKEN_KEY} from Secret ${TOKEN_SECRET} in ${HUB_NAMESPACE}" >&2
  exit 1
fi

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

echo "==> PATCH rh-certified remote (token from Secret/${TOKEN_SECRET})"
REMOTES="$(curl_hub GET "/api/galaxy/pulp/api/v3/remotes/ansible/collection/?name=rh-certified")"
REMOTE_HREF="$(echo "${REMOTES}" | jq -r '.results[0].pulp_href // empty')"
if [[ -z "${REMOTE_HREF}" ]]; then
  echo "remote rh-certified not found" >&2
  exit 1
fi

BODY="$(jq -n --arg t "${OFFLINE}" '{token: $t}')"
PATCH_OUT="$(curl_hub PATCH "${REMOTE_HREF}" "${BODY}")"
TASK_PATCH="$(echo "${PATCH_OUT}" | jq -r '.task // empty')"
if [[ -n "${TASK_PATCH}" && "${TASK_PATCH}" != "null" ]]; then
  [[ "${TASK_PATCH}" == http* ]] || TASK_PATCH="${HUB_GATEWAY_URL}${TASK_PATCH}"
  echo "    waiting for remote update task..."
  for _ in $(seq 1 90); do
    ST="$(curl_hub GET "${TASK_PATCH}" | jq -r '.state')"
    case "${ST}" in completed) break ;; failed|canceled)
      curl_hub GET "${TASK_PATCH}" | jq . >&2
      exit 1 ;;
    esac
    sleep 2
  done
fi

echo "==> POST sync repository rh-certified"
REPOS="$(curl_hub GET "/api/galaxy/pulp/api/v3/repositories/ansible/ansible/?name=rh-certified")"
REPO_HREF="$(echo "${REPOS}" | jq -r '.results[0].pulp_href // empty')"
if [[ -z "${REPO_HREF}" ]]; then
  echo "repository rh-certified not found" >&2
  exit 1
fi
SYNC_UP="${REPO_HREF%/}/sync/"
PAYLOAD="$(jq -n --arg r "${REMOTE_HREF}" '{remote: $r, mirror: false}')"
SYNC_RESP="$(curl_hub POST "${SYNC_UP}" "${PAYLOAD}")"
TASK_SYNC="$(echo "${SYNC_RESP}" | jq -r '.task // empty')"
if [[ -z "${TASK_SYNC}" || "${TASK_SYNC}" == "null" ]]; then
  echo "unexpected sync response: ${SYNC_RESP}" >&2
  exit 1
fi
[[ "${TASK_SYNC}" == http* ]] || TASK_SYNC="${HUB_GATEWAY_URL}${TASK_SYNC}"
echo "    task: ${TASK_SYNC}"

if [[ "${WAIT_FOR_SYNC}" != "true" ]]; then
  exit 0
fi

echo "==> Waiting for sync task (poll every 15s)"
deadline=$((SECONDS + 7200))
while (( SECONDS < deadline )); do
  TJSON="$(curl_hub GET "${TASK_SYNC}")"
  STATE="$(echo "${TJSON}" | jq -r '.state // empty')"
  case "${STATE}" in
    completed)
      echo "OK — rh-certified sync finished."
      curl -sk "${AUTH[@]}" "${HUB_GATEWAY_URL}/api/galaxy/v3/plugin/ansible/content/published/collections/index/?limit=1" | jq '.meta'
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
echo "Timed out waiting for sync" >&2
exit 1
