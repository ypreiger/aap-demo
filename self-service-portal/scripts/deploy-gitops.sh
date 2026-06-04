#!/usr/bin/env bash
# Register the Argo CD Application and wait until the portal Route exists.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAMESPACE="${NAMESPACE:-aap}"
RELEASE_NAME="${RELEASE_NAME:-aap-portal}"
ARGO_NS="${ARGO_NS:-openshift-gitops}"
APP_NAME="${APP_NAME:-aap-self-service-portal}"
CLUSTER_ROUTER_BASE="${CLUSTER_ROUTER_BASE:-}"

log() { printf '[deploy-gitops] %s\n' "$*"; }

command -v oc >/dev/null || { echo "oc required"; exit 1; }

if ! oc get secret secrets-rhaap-portal -n "$NAMESPACE" >/dev/null 2>&1; then
  log "Run scripts/bootstrap-secrets.sh first"
  exit 1
fi

oc apply -f "$ROOT/argocd/application.yaml"

log "Waiting for Argo CD Application to exist..."
for _ in $(seq 1 30); do
  oc get application "$APP_NAME" -n "$ARGO_NS" >/dev/null 2>&1 && break
  sleep 2
done

log "Trigger sync (if not already automated)..."
oc patch application "$APP_NAME" -n "$ARGO_NS" --type merge \
  -p '{"operation":{"initiatedBy":{"username":"deploy-gitops"},"sync":{}}}' 2>/dev/null || true

if [[ -z "$CLUSTER_ROUTER_BASE" ]]; then
  CLUSTER_ROUTER_BASE="$(oc get ingresscontroller cluster -o jsonpath='{.status.domain}' 2>/dev/null || true)"
fi
PORTAL_HOST="${RELEASE_NAME}-rhaap-portal-${NAMESPACE}.${CLUSTER_ROUTER_BASE}"
PORTAL_URL="https://${PORTAL_HOST}"

log "Waiting for Route (up to ~15 min)..."
for _ in $(seq 1 90); do
  if oc get route "${RELEASE_NAME}-rhaap-portal" -n "$NAMESPACE" >/dev/null 2>&1; then
    actual="$(oc get route "${RELEASE_NAME}-rhaap-portal" -n "$NAMESPACE" -o jsonpath='https://{.spec.host}')"
    PORTAL_URL="$actual"
    break
  fi
  sleep 10
done

ARGO_ROUTE="$(oc get route openshift-gitops-server -n "$ARGO_NS" -o jsonpath='https://{.spec.host}' 2>/dev/null || echo 'https://openshift-gitops-server-openshift-gitops.apps.<cluster>')"

cat <<EOF

Portal URL:  $PORTAL_URL
Argo CD UI:  $ARGO_ROUTE  (Application: $APP_NAME)

After the Route is live, confirm the OAuth redirect URI in AAP matches:
  ${PORTAL_URL}/api/auth/rhaap/handler/frame

EOF
