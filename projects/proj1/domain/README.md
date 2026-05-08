# Declarative domain inputs (proj1)

YAML here describes **intent** for non-OpenShift (and cross-cutting network) tooling. Ansible playbooks normalize and validate entries; mocks or real integrations consume the same shapes.

| File | Domain | Notes |
|------|--------|-------|
| `firewall_rules.yaml` | Firewall / NetworkPolicy adjunct | Logical rules; BOM `networkpolicy.yaml` remains canonical for kube; this file aids workshops comparing policy intent vs. mock firewall APIs. |
| `f5_service.yaml` | F5 BIG-IP (mock/real AS3 bridge) | Pool/vip/snippet placeholders. |
| `bluecoat_proxy.yaml` | Secure web gateway posture | Stub health/policy metadata. |
| `vmware_hints.yaml` | VMware / vCenter mock sync | Drives `domain_vmware` classification + nested mock playbook. |

Schemas are summarized in **`documentation/DOMAIN_INPUT_YAML.md`**.
