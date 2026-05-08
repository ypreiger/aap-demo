# Agent: OpenShift Virtualization engineer

## Scope

Namespaces & NetworkPolicies under `projects/*/bom`, playbooks **`project_foundation.yml`**, **`project_vms.yml`**, **`workshop_networkpolicy_audit.yml`**.

## Tasks

1. Preserve deterministic naming: namespace == `project_name`, SA `{{ project_name }}-sa`, NP `deny-all-open-443`.
2. When clusters lack advertised instancetypes, flip survey to **`manual`** mode and validate CPU/mem keys.
3. Surface **KubeVirt/CDI failure modes** (`DataVolume`, `VirtualMachineScheduling`) succinctly for presenter FAQ.
