#!/usr/bin/env bash
# Finds the first workflow_approval node (pending/waiting) under a WorkflowJob and approves it.
set -euo pipefail

CONTROLLER_HOST="${CONTROLLER_HOST:-}"
CONTROLLER_TOKEN="${CONTROLLER_TOKEN:-}"
WF_JOB_ID="${1:-}"

if [[ -z "${CONTROLLER_HOST}" || -z "${CONTROLLER_TOKEN}" || -z "${WF_JOB_ID}" ]]; then
  echo "usage: CONTROLLER_HOST=… CONTROLLER_TOKEN=… $0 <workflow_job_id>" >&2
  exit 1
fi

BASE="${CONTROLLER_HOST%/}"
[[ "$BASE" == */api ]] || BASE="${BASE}/api"

curl_api() {
  curl -sS -k -H "Authorization: Bearer ${CONTROLLER_TOKEN}" -H "Content-Type: application/json" "$@"
}

NODES=$(curl_api "${BASE}/v2/workflow_jobs/${WF_JOB_ID}/workflow_nodes/")
APPROVAL_ID=$(echo "$NODES" | jq -r '
  [.results[]?
    | select((.summary_fields.job.type // "") == "workflow_approval")
    | (.job // .summary_fields.job.id // empty)
  ] | .[0] // empty')

if [[ -z "${APPROVAL_ID}" || "${APPROVAL_ID}" == "null" ]]; then
  echo "No workflow_approval node job id found yet." >&2
  exit 3
fi

DET=$(curl_api "${BASE}/v2/workflow_approvals/${APPROVAL_ID}/")
STAT=$(echo "$DET" | jq -r '.status // empty')

case "${STAT,,}" in
  successful)
    echo "approval_job=${APPROVAL_ID} already finalized (${STAT})."
    exit 0
    ;;
  canceled|failed|error)
    echo "approval_job=${APPROVAL_ID} in terminal state ${STAT}; not approving." >&2
    exit 2
    ;;
esac

echo "approval_job=${APPROVAL_ID} status=${STAT}"
case "${STAT,,}" in
  pending|waiting)
    OUT=$(curl_api -X POST -d '{}' "${BASE}/v2/workflow_approvals/${APPROVAL_ID}/approve/")
    echo "$OUT" | jq '{id,status}' 2>/dev/null || echo "$OUT"
    ;;
  "")
    exit 3
    ;;
  *)
    echo "Unexpected approval status (${STAT}); not POSTing approve." >&2
    exit 4
    ;;
esac
