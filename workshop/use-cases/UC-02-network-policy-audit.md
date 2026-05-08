# UC-02 — Network policy posture audit

## Story

After virtualization assets land, a **read-only** Ansible pass validates the deny-all / selective egress policy and annotates the namespace for audit dashboards.

## Playbook

`playbooks/workshop_networkpolicy_audit.yml`

## Success criteria

- Asserts NetworkPolicy **`deny-all-open-443`** exists.
- Adds annotation `workshop.aap-demo.github.io/network-audit`.

## Failure modes

- Foundation skipped → assert fails (by design).
- SA token expired → `kubernetes.core` auth errors (rotate **openshift-bom-target** credential).
