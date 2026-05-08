# Workshop RBAC (Controller Teams + roles)

`tower.ansible.com` bundles on OpenShift lab clusters often omit `Team` CRs; we bootstrap teams via **`scripts/workshop-rbac-bootstrap.sh`** (OAuth token).

## Domain → team mapping

| Team | Responsibility |
|------|----------------|
| Workshop — OpenShift Virtualization | `bom-project-*`, `workshop-bom-project-vms`, inventory access |
| Workshop — Network Policy | `workshop-networkpolicy-audit` |
| Workshop — VMware | `workshop-mock-vmware` (later vendor creds) |
| Workshop — F5 | `workshop-mock-f5` |
| Workshop — Secure Web Gateway | Blue Coat mocks / future integrations |
| Workshop — Observers ReadOnly | dashboards / auditor |

## Grants (UI path)

Organizations → **Default** → Access → Teams → `<team>` → Roles → assign **Workflow / Job Execute** scoped to **`workshop-multi-domain`** plus any split job templates presenters want segmented.

Fine-grained DAB/API roles differ per patch level—use UI when scripts would be brittle.

## Verification

Logged-in team member launches **Survey** workflows but cannot edit objects outside assigned roles.
