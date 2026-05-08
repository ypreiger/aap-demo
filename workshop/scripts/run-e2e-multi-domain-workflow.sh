#!/usr/bin/env bash
# Applies mock infra (kustomize), applies tower CR overlay, syncs AnsibleProject, launches
# workflow workshop-multi-domain, auto-approves the gate, waits for workflow success.
#
# Requires: jq, oc, curl. Secret/aap-controller-api in namespace ${AAP_NAMESPACE:-aap}.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NS="${AAP_NAMESPACE:-aap}"

HOST=$(oc get secret -n "${NS}" aap-controller-api -o jsonpath='{.data.host}' | base64 -d | tr -d '\r\n' | sed 's|/*$||')
TOKEN=$(oc get secret -n "${NS}" aap-controller-api -o jsonpath='{.data.token}' | base64 -d | tr -d '\r\n')

echo "==> Apply mock infra"
oc apply -k "${ROOT}/workshop/openshift/mock-infra"
oc rollout status deployment/workshop-mock-infra -n "${NS}" --timeout=180s

MOCK_URL=$("${ROOT}/workshop/scripts/resolve-mock-route.sh")
echo "    mock_route=${MOCK_URL}"

echo "==> Apply tower CR bundle (includes workshop-multi-domain WT)"
oc apply -k "${ROOT}/aap-yamls/tower/"

echo "==> Refresh Git-backed project sync (collections + new playbooks)"
PROJ_JSON=$(curl -sS -k -H "Authorization: Bearer ${TOKEN}" "${HOST}/api/v2/projects/")
PROJ_ID=$(echo "${PROJ_JSON}" | jq -r '[.results[]? | select(.name == "AAP Demo (GitHub)")][0].id // empty')
if [[ -z "${PROJ_ID}" || "${PROJ_ID}" == "null" ]]; then
  echo "Project 'AAP Demo (GitHub)' missing in Controller." >&2
  exit 3
fi
curl -sS -k -X POST -H "Authorization: Bearer ${TOKEN}" \
  "${HOST}/api/v2/projects/${PROJ_ID}/update/" >/dev/null || true

echo "Waiting for Git project revision (polling) ..."
for _ in $(seq 1 40); do
  P=$(curl -sS -k -H "Authorization: Bearer ${TOKEN}" "${HOST}/api/v2/projects/${PROJ_ID}/")
  SYNC=$(echo "$P" | jq -r '.status // empty')
  SYNC_LC=$(echo "$SYNC" | tr '[:upper:]' '[:lower:]')
  if [[ "${SYNC_LC}" == "successful" ]]; then break; fi
  sleep 5
done

echo "==> Launch WorkflowJob workshop-multi-domain"
WT_ID=""
for _ in $(seq 1 60); do
  WT=$(curl -sS -k -H "Authorization: Bearer ${TOKEN}" "${HOST}/api/v2/workflow_job_templates/?name=workshop-multi-domain")
  WT_ID=$(echo "$WT" | jq -r '.results[0].id // empty')
  [[ -n "${WT_ID}" && "${WT_ID}" != "null" ]] && break
  sleep 10
done
INV=$(curl -sS -k -H "Authorization: Bearer ${TOKEN}" "${HOST}/api/v2/inventories/?name=Demo%20Inventory")
INV_ID=$(echo "$INV" | jq -r '.results[0].id // empty')
if [[ -z "${WT_ID}" || -z "${INV_ID}" ]]; then
  echo "Could not resolve WT or inventory (operator still reconciling?)." >&2
  exit 4
fi

BODY=$(jq -nc --argjson inv "$INV_ID" --arg p "proj1" --arg m "$MOCK_URL" \
  '{inventory: $inv, extra_vars: {project_name: $p, workshop_mock_base_url: $m}}')
LAUNCH=$(curl -sS -k -X POST -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" \
  -d "${BODY}" "${HOST}/api/v2/workflow_job_templates/${WT_ID}/launch/")
WFJ=$(echo "$LAUNCH" | jq -r '.id // empty')
if [[ -z "${WFJ}" ]]; then
  echo "Launch failed: ${LAUNCH}" >&2
  exit 5
fi
echo "    workflow_job_id=${WFJ}"

echo "==> Wait for approval node then auto-approve"
export CONTROLLER_HOST="$HOST" CONTROLLER_TOKEN="$TOKEN"
for _ in $(seq 1 60); do
  if "${ROOT}/workshop/scripts/auto-approve-pending-workflow.sh" "${WFJ}" 2>/dev/null; then
    break
  fi
  sleep 5
done

echo "==> Wait for workflow completion"
for _ in $(seq 1 120); do
  W=$(curl -sS -k -H "Authorization: Bearer ${TOKEN}" "${HOST}/api/v2/workflow_jobs/${WFJ}/")
  S=$(echo "$W" | jq -r '.status // empty')
  echo "    status=${S}"
  SLC=$(echo "$S" | tr '[:upper:]' '[:lower:]')
  case "${SLC}" in
    successful) exit 0 ;;
    failed|error|canceled) echo "$W" | jq '{status,status_text}' >&2; exit 6 ;;
  esac
  sleep 10
done
echo "Timeout waiting for workflow ${WFJ}" >&2
exit 7
