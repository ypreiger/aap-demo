#!/usr/bin/env bash
set -euo pipefail
# Deploy email-plugin into OpenShift namespace aap:
# apply manifests → create Secret → patch ConfigMap URLs → binary build → wait → rollout
#
# Override:
#   SMTP_PASSWORD=<gmail-app-password> DISABLE_SMTP=false ./scripts/deploy-email-plugin.sh

NS="${OPENSHIFT_PROJECT:-aap}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Applying kustomize from ${ROOT}/openshift (namespace=${NS})"
oc apply -k "${ROOT}/openshift"

SIGNING_SECRET="${SIGNING_SECRET:-$(openssl rand -hex 24)}"
CTRL_TOKEN="$(oc get secret aap-controller-api -n "${NS}" -o jsonpath='{.data.token}' | base64 -d)"
CTRL_HOST="$(oc get secret aap-controller-api -n "${NS}" -o jsonpath='{.data.host}' | base64 -d)"

if oc get secret email-plugin-secrets -n "${NS}" >/dev/null 2>&1; then
  echo "Secret email-plugin-secrets already exists; skip create (kubectl delete secret email-plugin-secrets -n ${NS} to recreate)."
else
  oc create secret generic email-plugin-secrets -n "${NS}" \
    --from-literal=SIGNING_SECRET="${SIGNING_SECRET}" \
    --from-literal=CONTROLLER_TOKEN="${CTRL_TOKEN}" \
    --from-literal=SMTP_PASSWORD="${SMTP_PASSWORD:-}" \
    --from-literal=WEBHOOK_HMAC_SECRET="${WEBHOOK_HMAC_SECRET:-}"
fi

DISABLE_SMTP="${DISABLE_SMTP:-true}"
test -n "${SMTP_PASSWORD:-}" && DISABLE_SMTP="false"

oc patch configmap/email-plugin-env -n "${NS}" --type merge -p "$(jq -nc \
  --arg h "${CTRL_HOST}" \
  --arg d "${DISABLE_SMTP}" \
  '{data:{CONTROLLER_HOST:$h,DISABLE_SMTP:$d}}')" >/dev/null

echo "Building image (binary) email-plugin ..."
# Do not use --follow --wait alone: many clients/server defaults cancel at ~300s before the build
# pod pulls the builder/runtime image or finishes layers. Split start + long oc wait instead.
BUILD_RESOURCE="$(oc start-build email-plugin --from-dir="${ROOT}" -o name -n "${NS}" --follow=false --wait=false)"
BUILD_NAME="${BUILD_RESOURCE##*/}"
readonly BUILD_BUILD="build.build.openshift.io/${BUILD_NAME}"
WAIT_SECS="${BUILD_WAIT_SECONDS:-2700}"
# Phase goes Running → Complete (success) or Failed/Cancelled/Error.
if ! oc wait --for=jsonpath='{.status.phase}'=Complete "${BUILD_BUILD}" -n "${NS}" --timeout="${WAIT_SECS}s"; then
  echo "Wait for build ${BUILD_NAME} failed or timed out. Phase/build:" >&2
  oc get "${BUILD_BUILD}" -n "${NS}" -o wide 2>&1 || true
  oc logs "${BUILD_BUILD}" -n "${NS}" --tail=120 2>&1 || true
  exit 1
fi

echo "Waiting for Deployment/email-plugin rollout ..."
oc rollout status deployment/email-plugin -n "${NS}" --timeout=240s || true

ROUTE_HOST="$(oc get route/email-plugin -n "${NS}" -o jsonpath='{.spec.host}')"
PUBLIC_BASE_URL="${PUBLIC_BASE_URL:-https://${ROUTE_HOST}}"
jqpatch="$(jq -nc --arg u "${PUBLIC_BASE_URL}" '{data:{PUBLIC_BASE_URL:$u}}')"
oc patch configmap/email-plugin-env -n "${NS}" --type merge -p "${jqpatch}" >/dev/null

if [[ -n "${CONTROLLER_UI_PUBLIC_URL:-}" ]]; then
  oc patch configmap/email-plugin-env -n "${NS}" --type merge -p "$(
    jq -nc --arg u "${CONTROLLER_UI_PUBLIC_URL}" '{data:{CONTROLLER_UI_PUBLIC_URL:$u}}'
  )" >/dev/null
fi

if [[ -n "${CONTROLLER_WORKFLOW_JOB_UI_PATH_TEMPLATE:-}" ]]; then
  oc patch configmap/email-plugin-env -n "${NS}" --type merge -p "$(
    jq -nc --arg u "${CONTROLLER_WORKFLOW_JOB_UI_PATH_TEMPLATE}" \
      '{data:{CONTROLLER_WORKFLOW_JOB_UI_PATH_TEMPLATE:$u}}'
  )" >/dev/null
fi

oc rollout restart deployment/email-plugin -n "${NS}"
oc rollout status deployment/email-plugin -n "${NS}" --timeout=240s || true

echo "email-plugin HTTPS base: ${PUBLIC_BASE_URL}"
echo "Webhook URL for Controller: ${PUBLIC_BASE_URL%/}/v1/hooks/controller"
