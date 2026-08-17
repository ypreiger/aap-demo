#!/usr/bin/env bash
# Trigger AAP job-template catalog sync on the automation portal backend.
# The portal plugin route is /api/catalog/ansible/sync/... (not /api/ansible/...).
set -euo pipefail

NAMESPACE="${NAMESPACE:-aap}"
RELEASE="${RELEASE:-aap-portal}"
ROUTE="${ROUTE:-aap-portal-rhaap-portal}"

HOST="$(oc get route "$ROUTE" -n "$NAMESPACE" -o jsonpath='{.spec.host}')"
BASE="https://${HOST}"
SECRET="$(oc get secret aap-portal-auth -n "$NAMESPACE" -o jsonpath='{.data.backend-secret}' | base64 -d)"

log() { printf '[refresh-catalog] %s\n' "$*"; }

TOKEN="$(python3 - "$SECRET" <<'PY'
import sys, time
try:
    import jwt
except ImportError:
    sys.exit("PyJWT required: python3 -m pip install pyjwt")
secret = sys.argv[1]
now = int(time.time())
print(jwt.encode(
    {
        "iss": "legacy-default-config",
        "sub": "legacy-default-config",
        "iat": now,
        "exp": now + 3600,
        "aud": "backstage",
    },
    secret,
    algorithm="HS256",
))
PY
)"

auth=(-H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json")

for path in \
  '/api/catalog/entities?filter=kind=template&limit=1' \
  '/api/catalog/ansible/sync/from-aap/job_templates' \
  ; do
  code=$(curl -sk "${auth[@]}" -o /tmp/refresh-body.txt -w '%{http_code}' "${BASE}${path}" || echo 000)
  log "${path} -> HTTP ${code}"
  head -c 300 /tmp/refresh-body.txt 2>/dev/null; echo
done

log "Open Self-Service → Create Task and look for: Temporary ACS Policy Exception"
log "Clear tag filters (do not leave openshift-virtualization selected)."
