#!/usr/bin/env bash
# Prints https://hostname for Route/workshop-mock-infra in namespace ${AAP_NAMESPACE:-aap}.
set -euo pipefail
NS="${AAP_NAMESPACE:-aap}"
RAW=$(oc get route workshop-mock-infra -n "$NS" -o jsonpath='{.spec.host}' 2>/dev/null || true)
if [[ -z "${RAW:-}" ]]; then
  exit 2
fi
echo "https://${RAW}"
