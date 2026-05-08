#!/usr/bin/env bash
# Optional hygiene: deletes known-stale Kubernetes Tower CR duplicates and prints Controller API
# names to prune manually when UI clutter remains after operator drift.
#
# Usage:
#   AAP_NAMESPACE=aap bash scripts/workshop-aap-cleanup-unused.sh
#
# Add --dry-run as first arg to skip oc delete sections (API side still lists).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NS="${AAP_NAMESPACE:-aap}"

if [[ "${1:-}" == "--dry-run" ]]; then
  echo "(dry-run) skipping oc delete fragments"
fi

"${ROOT}/aap-yamls/scripts/cleanup-legacy-bom-resources.sh"

declare -a CRDeletes=(
)
# Extend here if experimenting with ephemeral Tower CR prototypes.

echo "Removing orphan AnsibleWorkflow test CRs labelled workshop (if labelled) ..."
if [[ "${1:-}" != "--dry-run" ]]; then
  oc delete ansibleworkflow \
    -n "${NS}" \
    -l 'workshop-run=true' \
    --ignore-not-found
fi

echo ""
echo "== Controller objects to review manually"
HOST=$(oc get secret -n "${NS}" aap-controller-api -o jsonpath='{.data.host}' | base64 -d | sed 's|/*$||')
TOKEN=$(oc get secret -n "${NS}" aap-controller-api -o jsonpath='{.data.token}' | base64 -d)

BASE="${HOST%/}"
[[ "$BASE" == */api ]] || BASE="${BASE}/api"

curl -sS -k -H "Authorization: Bearer ${TOKEN}" "${BASE}/v2/job_templates/" \
  | jq -r '[.results[]? | select((.name|ascii_downcase)|test("_old|deprecated|zzz"))]|map(.name)'

echo "(Delete via UI/API if undesired)"
