# UC-02 — Network policy posture audit

## Goal

Run a **read-only** playbook that validates NetworkPolicy posture and annotates the namespace for audit.

## Prerequisites

Follow **`../workshop/PLAN.md`**. Hub + Controller collections: **[`UC-05-inspect-hub-collections-bluecoat.md`](USECASE_UC05_inspect_hub_collections_bluecoat.md)**, **`./COLLECTION_CONTROLLER.md`**.

To run **only** this job template in isolation, ensure inventory and credential **`openshift-bom-target`** exist. In **`workshop-multi-domain`** it runs after earlier workflow nodes.

---

## Instructions (step-by-step in AAP)

### Typical path — as part of **`workshop-multi-domain`**

1. Complete **UC-01** through the approval gate and **`workshop-bom-project-vms`** (foundation + VMs must exist first).
2. Stay on the running **workflow job** detail view (**Jobs** → your **`workshop-multi-domain`** instance).
3. When the **`workshop-networkpolicy-audit`** node starts, click into that **job** (not only the workflow row).
4. Read **Output:**
   - Assert messages for **`NetworkPolicy`** named **`deny-all-open-443`** (exact name checked by playbook **`../playbooks/workshop_networkpolicy_audit.yml`**).
   - Annotation **`workshop.aap-demo.github.io/network-audit`** applied to namespace.

### What you should see

| Item | Meaning |
|------|---------|
| **Status** | **`Successful`** unless foundation SKIPPED (**by design**) or **`kubernetes.core` auth** broke (rotate **`openshift-bom-target`**). |
| **Log** | No failed **assertions** — policy present and annotation echoed. |

### Standalone run (operators only)

1. **Templates** → **Job Templates** → **`workshop-networkpolicy-audit`**.
2. Provide **`extra_vars`** matching your target namespace (**`project_name`** / BOM convention used by BOM playbooks)—only if supported by inventory and credentials in your tenant; default workshop path is embedded in **UC-01** workflow.

---

## Playbook

`../playbooks/workshop_networkpolicy_audit.yml`

## Success criteria

- Asserts NetworkPolicy **`deny-all-open-443`** exists.
- Adds annotation `workshop.aap-demo.github.io/network-audit`.

## Failure modes

- Foundation skipped → assert fails (by design).
- SA token expired → `kubernetes.core` auth errors (rotate **openshift-bom-target** credential).

## See also

- **[`../CLIENT_RUNBOOK.md`](../CLIENT_RUNBOOK.md)** §6 node table (order after VMs).
