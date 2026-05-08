#!/usr/bin/env bash
set -euo pipefail
NS="${AAP_NAMESPACE:-aap}"
EDA_HOST=$(oc get eda demo-aap-eda -n "${NS}" -o jsonpath='{.status.URL}' 2>/dev/null | sed 's|/*$||')
if [[ -z "${EDA_HOST}" ]]; then
  echo "Could not read EDA status.URL (CR demo-aap-eda missing?)." >&2
  exit 2
fi
code=$(curl -sk -o /dev/null -w '%{http_code}' "${EDA_HOST}/")
echo "eda_route=${EDA_HOST} http_status=${code}"
[[ "${code}" == "200" || "${code}" == "302" ]] || exit 3
