#!/usr/bin/env bash
# Repair Automation Controller objects for UC-07 when Tower Resource Operator reconciles JT/WT
# with status "There was an error in the job template/workflow template" but project sync succeeded.
#
# Ensures Job Templates email-e2e-create-namespace / email-e2e-apply-netpol exist with
# openshift-bom-target credential, then builds the email-e2e-ns-netpol workflow visualizer edges.
#
# Prereqs: jq, curl, oc. Secret/aap-controller-api in ${AAP_NAMESPACE:-aap}.
#
set -euo pipefail

NS="${AAP_NAMESPACE:-aap}"
ORG_NAME="${ORG_NAME:-Default}"
PROJ_NAME="${PROJ_NAME:-AAP Demo (GitHub)}"
INV_NAME="${INV_NAME:-Demo Inventory}"
CRED_NAME="${CRED_NAME:-openshift-bom-target}"
WJT_NAME="${WJT_NAME:-email-e2e-ns-netpol}"

HOST=$(oc get secret -n "${NS}" aap-controller-api -o jsonpath='{.data.host}' | base64 -d | tr -d '\r\n' | sed 's|/*$||')
TOKEN=$(oc get secret -n "${NS}" aap-controller-api -o jsonpath='{.data.token}' | base64 -d | tr -d '\r\n')

api() {
  curl -sS -k -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" "$@"
}

# Default API page size truncates lists; WT missing from results looks like operator never created nodes.
PAGE="page_size=500"

echo "==> Resolve org / project / inventory / credential (encode-safe; names may contain spaces)"
ORG_ID=$(api "${HOST}/api/v2/organizations/?${PAGE}" | jq -r --arg n "${ORG_NAME}" '[.results[]? | select(.name == $n)][0].id // empty')
PROJ_JSON=$(api "${HOST}/api/v2/projects/?${PAGE}")
PROJ_ID=$(echo "${PROJ_JSON}" | jq -r --arg n "${PROJ_NAME}" '[.results[]? | select(.name == $n)][0].id // empty')
INV_JSON=$(api "${HOST}/api/v2/inventories/?${PAGE}")
INV_ID=$(echo "${INV_JSON}" | jq -r --arg n "${INV_NAME}" '[.results[]? | select(.name == $n)][0].id // empty')
CRED_ID=$(api "${HOST}/api/v2/credentials/?${PAGE}" | jq -r --arg n "${CRED_NAME}" '[.results[]? | select(.name == $n)][0].id // empty')
WJT_ID=$(api "${HOST}/api/v2/workflow_job_templates/?${PAGE}" | jq -r --arg n "${WJT_NAME}" '[.results[]? | select(.name == $n)][0].id // empty')
# Workflow approval UJT is not exposed reliably by name on all API versions; copy PK from bom-project-deploy graph.
BOM_WT_ID=$(api "${HOST}/api/v2/workflow_job_templates/?${PAGE}" | jq -r --arg n "bom-project-deploy" '[.results[]? | select(.name == $n)][0].id // empty')
APR_ID=$(api "${HOST}/api/v2/workflow_job_templates/${BOM_WT_ID}/workflow_nodes/" \
  | jq -r '.results[]? | select(.summary_fields.unified_job_template.unified_job_type == "workflow_approval") | .unified_job_template' | head -1)

if [[ -z "${ORG_ID}" || -z "${PROJ_ID}" || -z "${INV_ID}" || -z "${CRED_ID}" || -z "${WJT_ID}" || -z "${BOM_WT_ID}" || -z "${APR_ID}" ]]; then
  echo "Missing prerequisite in Controller:" >&2
  echo "  org=${ORG_ID} project=${PROJ_ID} inv=${INV_ID} cred=${CRED_ID} wjt=${WJT_ID} bom_wt=${BOM_WT_ID} approval_ujt_pk=${APR_ID}" >&2
  exit 2
fi

jt_ensure() {
  local name="$1" playbook="$2"
  local jid
  jid=$(api "${HOST}/api/v2/job_templates/?${PAGE}" | jq -r --arg n "${name}" '[.results[]? | select(.name == $n)][0].id // empty')
  if [[ -z "${jid}" ]]; then
    echo "    creating JobTemplate ${name}"
    jid=$(jq -nc \
      --arg n "$name" \
      --argjson org "$ORG_ID" \
      --argjson proj "$PROJ_ID" \
      --argjson inv "$INV_ID" \
      --arg pb "$playbook" \
      '{name:$n, job_type:"run", organization:$org, project:$proj, inventory:$inv, playbook:$pb}' \
      | api -X POST -d @- "${HOST}/api/v2/job_templates/" | jq -r '.id')
  fi
  local has
  has=$(api "${HOST}/api/v2/job_templates/${jid}/credentials/" | jq "[.results[]|.id]|index(${CRED_ID})!=null")
  if [[ "${has}" != "true" ]]; then
    echo "    attaching credential ${CRED_NAME} to JT ${name} (${jid})"
    api -X POST -d "$(jq -nc --argjson id "${CRED_ID}" '{id:$id}')" \
      "${HOST}/api/v2/job_templates/${jid}/credentials/" >/dev/null || true
  fi
  echo "${jid}"
}

echo "==> Ensure job templates (API)"
JT_CREATE=$(jt_ensure "email-e2e-create-namespace" "playbooks/email_e2e_create_namespace.yml")
JT_NETPOL=$(jt_ensure "email-e2e-apply-netpol" "playbooks/email_e2e_apply_netpol.yml")
echo "    email-e2e-create-namespace id=${JT_CREATE}"
echo "    email-e2e-apply-netpol id=${JT_NETPOL}"

echo "==> Ensure workflow_job_template_nodes for ${WJT_NAME} (${WJT_ID})"
WJ_NODES_JSON=$(api "${HOST}/api/v2/workflow_job_templates/${WJT_ID}/workflow_nodes/?${PAGE}")
CNT=$(echo "${WJ_NODES_JSON}" | jq -r '.count // 0')
NEED_GRAPH=1
HAVE_IDS="$(echo "${WJ_NODES_JSON}" | jq -r '[.results[]?.identifier // empty] | @json')"
if [[ "${CNT}" -eq 3 ]] && [[ "${HAVE_IDS}" == *'"e2e-create-ns"'* ]] && [[ "${HAVE_IDS}" == *'"e2e-approve-mail"'* ]] && [[ "${HAVE_IDS}" == *'"e2e-netpol"'* ]]; then
  S15=$(echo "${WJ_NODES_JSON}" | jq -r '[.results[] | select(.identifier == "e2e-create-ns")] | .[0].success_nodes[]? // empty')
  S16=$(echo "${WJ_NODES_JSON}" | jq -r '[.results[] | select(.identifier == "e2e-approve-mail")] | .[0].success_nodes[]? // empty')
  if [[ -n "${S15}" && -n "${S16}" ]]; then
    NEED_GRAPH=0
  fi
fi

if [[ "${NEED_GRAPH}" -eq 1 ]]; then
  echo "    rebuilding ${CNT} workflow node(s)"
  while IFS= read -r nid; do
    [[ -z "${nid}" ]] && continue
    api -X DELETE "${HOST}/api/v2/workflow_job_template_nodes/${nid}/" >/dev/null || true
  done < <(api "${HOST}/api/v2/workflow_job_templates/${WJT_ID}/workflow_nodes/?${PAGE}" | jq -r '.results[]?.id')
  sleep 2
  N1=$(jq -nc --argjson w "$WJT_ID" --argjson j "$JT_CREATE" \
    '{workflow_job_template:$w, unified_job_template:$j, identifier:"e2e-create-ns"}' \
    | api -X POST -d @- "${HOST}/api/v2/workflow_job_template_nodes/" | jq -r '.id')
  N2=$(jq -nc --argjson w "$WJT_ID" --argjson j "$APR_ID" \
    '{workflow_job_template:$w, unified_job_template:$j, identifier:"e2e-approve-mail"}' \
    | api -X POST -d @- "${HOST}/api/v2/workflow_job_template_nodes/" | jq -r '.id')
  N3=$(jq -nc --argjson w "$WJT_ID" --argjson j "$JT_NETPOL" \
    '{workflow_job_template:$w, unified_job_template:$j, identifier:"e2e-netpol"}' \
    | api -X POST -d @- "${HOST}/api/v2/workflow_job_template_nodes/" | jq -r '.id')
  if [[ -z "${N1}" || "${N1}" == "null" ]] || [[ -z "${N2}" || "${N2}" == "null" ]] || [[ -z "${N3}" || "${N3}" == "null" ]]; then
    echo "Failed to POST workflow_job_template_nodes (check Controller API stderr above)." >&2
    exit 3
  fi
  api -X POST -d "$(jq -nc --argjson id "$N2" '{associate:true,id:$id}')" \
    "${HOST}/api/v2/workflow_job_template_nodes/${N1}/success_nodes/" >/dev/null
  api -X POST -d "$(jq -nc --argjson id "$N3" '{associate:true,id:$id}')" \
    "${HOST}/api/v2/workflow_job_template_nodes/${N2}/success_nodes/" >/dev/null
  echo "    nodes=${N1} -> ${N2} -> ${N3}; refresh Workflow Visualizer tab (count below)"
  api "${HOST}/api/v2/workflow_job_templates/${WJT_ID}/workflow_nodes/?${PAGE}" | jq '{count}'
else
  echo "    workflow graph already wired"
fi

echo "Bootstrap complete."
