#!/usr/bin/env bash
# Apply tower CRs, sync Git project, launch workflow email-e2e-ns-netpol, optionally API-approve gate.
#
# Requires: jq, oc, curl. Secret/aap-controller-api in ${AAP_NAMESPACE:-aap}.
#
# Env:
#   TARGET_NAMESPACE — survey value (default: email-e2e-<unix_ts>)
#   AUTO_APPROVE     — if true (default), POST approve when gate is pending (no mail needed).
#                      Set false to test email-plugin Approve/Deny only.
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NS="${AAP_NAMESPACE:-aap}"

AUTO_APPROVE="${AUTO_APPROVE:-true}"
TARGET_NAMESPACE="${TARGET_NAMESPACE:-email-e2e-$(date +%s)}"

HOST=$(oc get secret -n "${NS}" aap-controller-api -o jsonpath='{.data.host}' | base64 -d | tr -d '\r\n' | sed 's|/*$||')
TOKEN=$(oc get secret -n "${NS}" aap-controller-api -o jsonpath='{.data.token}' | base64 -d | tr -d '\r\n')

echo "==> Apply tower bundle (WorkflowTemplate/JTs for email-e2e)"
oc apply -k "${ROOT}/aap-yamls/tower/"

echo "==> Refresh Git-backed project sync"
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

WT_ID=""
for _ in $(seq 1 60); do
  WT=$(curl -sS -k -H "Authorization: Bearer ${TOKEN}" "${HOST}/api/v2/workflow_job_templates/?name=email-e2e-ns-netpol")
  WT_ID=$(echo "$WT" | jq -r '.results[0].id // empty')
  [[ -n "${WT_ID}" && "${WT_ID}" != "null" ]] && break
  sleep 10
done
INV=$(curl -sS -k -H "Authorization: Bearer ${TOKEN}" "${HOST}/api/v2/inventories/?name=Demo%20Inventory")
INV_ID=$(echo "$INV" | jq -r '.results[0].id // empty')
if [[ -z "${WT_ID}" || -z "${INV_ID}" ]]; then
  echo "Could not resolve workflow template 'email-e2e-ns-netpol' or 'Demo Inventory'." >&2
  echo "Is the Ansible Automation Platform Resource Operator reconciling tower CRs?" >&2
  exit 4
fi

echo "==> Launch WorkflowJob email-e2e-ns-netpol (target_namespace=${TARGET_NAMESPACE})"
BODY=$(jq -nc --argjson inv "$INV_ID" --arg ns "${TARGET_NAMESPACE}" \
  '{inventory: $inv, extra_vars: {target_namespace: $ns}}')
LAUNCH=$(curl -sS -k -X POST -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" \
  -d "${BODY}" "${HOST}/api/v2/workflow_job_templates/${WT_ID}/launch/")
WFJ=$(echo "$LAUNCH" | jq -r '.id // empty')
if [[ -z "${WFJ}" ]]; then
  echo "Launch failed: ${LAUNCH}" >&2
  exit 5
fi
echo "    workflow_job_id=${WFJ}"
echo "    target_namespace=${TARGET_NAMESPACE}"

if [[ "${AUTO_APPROVE}" == "true" || "${AUTO_APPROVE}" == "1" || "${AUTO_APPROVE}" == "yes" ]]; then
  echo "==> Wait for approval node then API-approve (AUTO_APPROVE=true)"
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
      successful) echo "SUCCESS — check: oc get ns ${TARGET_NAMESPACE}; oc get netpol -n ${TARGET_NAMESPACE}"; exit 0 ;;
      failed|error|canceled) echo "$W" | jq '{status,status_text}' >&2; exit 6 ;;
    esac
    sleep 10
  done
  echo "Timeout waiting for workflow ${WFJ}" >&2
  exit 7
else
  echo "AUTO_APPROVE=false — approve in UI or mail; workflow_job_id=${WFJ}"
  exit 0
fi
