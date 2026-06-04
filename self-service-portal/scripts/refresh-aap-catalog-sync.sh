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

log "Open Self-Service → Create Task and filter tags: openshift-virtualization"
