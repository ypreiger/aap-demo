#!/usr/bin/env bash
# Creates Controller Teams (one per domain silo). Grant Execute on JT/WT via Org Admin UI
# or rbac API — Teams alone are scaffolding.
set -euo pipefail
NS="${AAP_NAMESPACE:-aap}"
HOST=$(oc get secret -n "${NS}" aap-controller-api -o jsonpath='{.data.host}' | base64 -d | tr -d '\r\n' | sed 's|/*$||')
TOKEN=$(oc get secret -n "${NS}" aap-controller-api -o jsonpath='{.data.token}' | base64 -d | tr -d '\r\n')

BASE="${HOST%/}"
[[ "$BASE" == */api ]] || BASE="${BASE}/api"

curl_api() {
  curl -sS -k -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" "$@"
}

ORG_JSON=$(curl_api "${BASE}/v2/organizations/")
ORG_ID=$(echo "$ORG_JSON" | jq -r --arg n Default '[.results[]? | select(.name == $n) | .id][0] // empty')

if [[ -z "${ORG_ID}" ]]; then
  echo "Organization Default missing." >&2
  exit 1
fi

ensure_team() {
  local tn="$1"
  local ENC TD
  ENC=$(jq -rn --arg s "$tn" '$s|@uri')
  TD=$(curl_api "${BASE}/v2/teams/?organization=${ORG_ID}&search=${ENC}")
  local TID
  TID=$(echo "$TD" | jq -r --arg nm "$tn" '[.results[]? | select(.name == $nm) | .id][0] // empty')
  if [[ -n "${TID}" && "${TID}" != "null" ]]; then
    echo "Team exists: ${tn} id=${TID}"
    return
  fi
  OUT=$(curl_api -X POST -d "$(jq -nc --arg n "$tn" --argjson o "$ORG_ID" '{name:$n, description:"workshop auto", organization:$o}')" "${BASE}/v2/teams/")
  TID=$(echo "$OUT" | jq -r '.id // empty')
  echo "Created team ${tn} id=${TID}"
}

ensure_team "Workshop OpenShiftVirt"
ensure_team "Workshop NetworkPolicy"
ensure_team "Workshop VMware"
ensure_team "Workshop F5"
ensure_team "Workshop SecureWebGW"
ensure_team "Workshop ObserversRO"

echo "Teams ready. Assign workflow/job permissions manually (Default org admin) — see workshop/WORKSHOP_RBAC.md"
