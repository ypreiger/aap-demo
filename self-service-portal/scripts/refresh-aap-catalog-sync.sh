#!/usr/bin/env bash
# Trigger AAP job-template catalog sync on the automation portal backend.
# Route is POST /api/catalog/ansible/sync/from-aap/job_templates (auth required).
set -euo pipefail

NAMESPACE="${NAMESPACE:-aap}"
ROUTE="${ROUTE:-aap-portal-rhaap-portal}"

HOST="$(oc get route "$ROUTE" -n "$NAMESPACE" -o jsonpath='{.spec.host}')"
BASE="https://${HOST}"

log() { printf '[refresh-catalog] %s\n' "$*"; }

if [[ -z "${PORTAL_CATALOG_TOKEN:-}" ]]; then
  log "Set PORTAL_CATALOG_TOKEN to a portal backend static/service token, or click"
  log "  Self-Service → Create Task refresh in the UI as an AAP admin."
  log "Expected item: Temporary ACS Policy Exception (clear tag filters)."
  log "Status (unauthenticated probe):"
  code=$(curl -sk -o /tmp/refresh-body.txt -w '%{http_code}' \
    "${BASE}/api/catalog/ansible/sync/status" || echo 000)
  log "GET /api/catalog/ansible/sync/status -> HTTP ${code}"
  exit 0
fi

code=$(curl -sk -X POST \
  -H "Authorization: Bearer ${PORTAL_CATALOG_TOKEN}" \
  -o /tmp/refresh-body.txt -w '%{http_code}' \
  "${BASE}/api/catalog/ansible/sync/from-aap/job_templates" || echo 000)
log "POST /api/catalog/ansible/sync/from-aap/job_templates -> HTTP ${code}"
head -c 300 /tmp/refresh-body.txt 2>/dev/null; echo

code=$(curl -sk \
  -H "Authorization: Bearer ${PORTAL_CATALOG_TOKEN}" \
  -o /tmp/refresh-body.txt -w '%{http_code}' \
  "${BASE}/api/catalog/ansible/sync/status" || echo 000)
log "GET /api/catalog/ansible/sync/status -> HTTP ${code}"
head -c 400 /tmp/refresh-body.txt 2>/dev/null; echo

log "Open Self-Service → Create Task → Temporary ACS Policy Exception"
log "Clear tag filters (do not leave openshift-virtualization selected)."
