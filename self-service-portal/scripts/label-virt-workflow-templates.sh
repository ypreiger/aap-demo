#!/usr/bin/env bash
# Apply openshift-virtualization / self-service labels to Controller workflow job templates
# (WorkflowTemplate CR spec.labels is not supported — use API).
set -euo pipefail

NAMESPACE="${NAMESPACE:-aap}"
LABELS='openshift-virtualization self-service'
TEMPLATES="${*:-bom-project-deploy workshop-multi-domain}"

GW_POD="$(oc get pod -n "$NAMESPACE" -o name | grep demo-aap-gateway | grep -v Terminating | head -1 | sed 's|pod/||')"
PASS="$(oc get secret demo-aap-admin-password -n "$NAMESPACE" -o jsonpath='{.data.password}' | base64 -d)"

api() {
  oc exec -n "$NAMESPACE" "$GW_POD" -c api -- \
    curl -sk -u "admin:${PASS}" "http://127.0.0.1:8000$1" "${@:2}"
}

for name in $TEMPLATES; do
  id="$(api "/api/controller/v2/workflow_job_templates/?name=${name}" | python3 -c "import sys,json; r=json.load(sys.stdin)['results']; print(r[0]['id'] if r else '')")"
  [[ -n "$id" ]] || { echo "skip: workflow ${name} not found"; continue; }
  for label in $LABELS; do
    api "/api/controller/v2/workflow_job_templates/${id}/labels/" -X POST \
      -H 'Content-Type: application/json' \
      -d "{\"name\":\"${label}\",\"organization\":1}" >/dev/null 2>&1 || true
    echo "labeled workflow ${name} (${id}): ${label}"
  done
done

echo "Run: ./self-service-portal/scripts/refresh-aap-catalog-sync.sh"
