#!/usr/bin/env bash
# Builds + deploys git-webhook-bridge into OPENSHIFT_PROJECT (default aap).
# Patches Controller + mock URLs from Secrets/Routes unless overridden.
#
# Optional env:
#   EDA_WEBHOOK_URL=https://.../ingress/activation/UUID/...
#   GITHUB_WEBHOOK_SECRET=your-github-repo-secret (recommended)
set -euo pipefail

NS="${OPENSHIFT_PROJECT:-aap}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Applying kustomize from ${REPO}/openshift (namespace=${NS})"
oc apply -k "${REPO}/openshift"

ROOT_TOP="$(cd "${REPO}/../.." && pwd)"
CTRL_TOKEN="$(oc get secret aap-controller-api -n "${NS}" -o jsonpath='{.data.token}' | base64 -d | tr -d '\r\n')"
CTRL_HOST="$(oc get secret aap-controller-api -n "${NS}" -o jsonpath='{.data.host}' | base64 -d | tr -d '\r\n')"

MOCK_URL=""
if MOCK_TRY="$("${ROOT_TOP}/workshop/scripts/resolve-mock-route.sh" 2>/dev/null)"; then
  MOCK_URL="${MOCK_TRY}"
fi

if oc get secret git-webhook-bridge-secrets -n "${NS}" >/dev/null 2>&1; then
  echo "Secret git-webhook-bridge-secrets exists — patch tokens manually if needed."
else
  oc create secret generic git-webhook-bridge-secrets -n "${NS}" \
    --from-literal=CONTROLLER_TOKEN="${CTRL_TOKEN}" \
    --from-literal=EDA_WEBHOOK_TOKEN="${EDA_WEBHOOK_TOKEN:-}" \
    --from-literal=GITHUB_WEBHOOK_SECRET="${GITHUB_WEBHOOK_SECRET:-}"
fi

CM_PATCH="$(jq -nc \
  --arg h "${CTRL_HOST}" \
  --arg m "${MOCK_URL:-}" \
  --arg eu "${EDA_WEBHOOK_URL:-}" \
  '({data:{CONTROLLER_HOST:$h}})
    | if ($m|length)>0 then .data.WORKFLOW_MOCK_BASE_URL = $m else . end
    | if ($eu|length)>0 then .data.EDA_WEBHOOK_URL = $eu else . end
  ')"

oc patch configmap/git-webhook-bridge-env -n "${NS}" --type merge -p "${CM_PATCH}" >/dev/null || true

echo "Starting binary BuildConfig git-webhook-bridge ..."
BUILD_RESOURCE="$(oc start-build git-webhook-bridge --from-dir="${REPO}" -o name -n "${NS}" --follow=false --wait=false)"
BUILD_NAME="${BUILD_RESOURCE##*/}"
WAIT_SECS="${BUILD_WAIT_SECONDS:-2700}"

if ! oc wait --for=jsonpath='{.status.phase}'=Complete \
  "build.build.openshift.io/${BUILD_NAME}" \
  -n "${NS}" --timeout="${WAIT_SECS}s"; then
  echo "Wait for build failed" >&2
  oc logs "build.build.openshift.io/${BUILD_NAME}" -n "${NS}" --tail=120 2>&1 || true
  exit 1
fi

oc rollout status deployment/git-webhook-bridge -n "${NS}" --timeout=240s || true

RHOST="$(oc get route/git-webhook-bridge -n "${NS}" -o jsonpath='{.spec.host}')"
echo "Git webhook HTTPS: https://${RHOST%/}/v1/github"
echo "Next: gh repo webhook -> https://${RHOST%/}/v1/github (+ secret if configured)"
