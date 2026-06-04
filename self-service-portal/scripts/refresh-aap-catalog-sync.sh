#!/usr/bin/env bash
# Trigger AAP job/workflow template catalog sync on the automation portal backend.
set -euo pipefail

NAMESPACE="${NAMESPACE:-aap}"
RELEASE="${RELEASE:-aap-portal}"
ROUTE="${ROUTE:-aap-portal-rhaap-portal}"

HOST="$(oc get route "$ROUTE" -n "$NAMESPACE" -o jsonpath='{.spec.host}')"
BASE="https://${HOST}"

log() { printf '[refresh-catalog] %s\n' "$*"; }

for path in \
  '/api/catalog/entities/by-query?limit=1' \
  '/api/ansible/sync/from-aap/job_templates' \
  ; do
  code=$(curl -sk -o /tmp/refresh-body.txt -w '%{http_code}' "${BASE}${path}" 2>/dev/null || echo 000)
  log "${path} -> HTTP ${code}"
  head -c 200 /tmp/refresh-body.txt 2>/dev/null; echo
done

log "Trigger Automation Hub collection sync (pahCollections)"
code=$(curl -sk -o /tmp/refresh-body.txt -w '%{http_code}' \
  -X POST "${BASE}/api/ansible/sync/from-aap/content" \
  -H 'Content-Type: application/json' \
  -d '{"filters":[{"repository_name":"community"},{"repository_name":"published"}]}' \
  2>/dev/null || echo 000)
log "POST /api/ansible/sync/from-aap/content -> HTTP ${code}"
head -c 400 /tmp/refresh-body.txt 2>/dev/null; echo

code=$(curl -sk -o /tmp/refresh-body.txt -w '%{http_code}' \
  "${BASE}/api/ansible/sync/status?ansible_contents=true" 2>/dev/null || echo 000)
log "GET /api/ansible/sync/status?ansible_contents=true -> HTTP ${code}"
head -c 400 /tmp/refresh-body.txt 2>/dev/null; echo

log "Open Self-Service → Collections (Hub) and Create Task (filter: openshift-virtualization)"
