#!/usr/bin/env bash
# Attach email-plugin webhook to workflow template email-e2e-ns-netpol (approval channel).
# Prereq: email-plugin deployed; oc login; Secret aap-controller-api in namespace aap.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NS="${AAP_NAMESPACE:-aap}"

EP="$(oc get route email-plugin -n "${NS}" -o jsonpath='{.spec.host}')"
WH="https://${EP}/v1/hooks/controller"
CH="$(oc get secret aap-controller-api -n "${NS}" -o jsonpath='{.data.host}' | base64 -d)"
TK="$(oc get secret aap-controller-api -n "${NS}" -o jsonpath='{.data.token}' | base64 -d)"

ansible-playbook "${ROOT}/email-plugin/playbooks/register_controller_webhook_notification.yml" \
  -e controller_host="$CH" \
  -e controller_oauth_token="$TK" \
  -e webhook_target_url="$WH" \
  -e workflow_name=email-e2e-ns-netpol \
  -e notification_name=email-e2e-email-plugin-webhook
