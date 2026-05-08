# UC-07 — Email E2E: create Namespace → Approve/Deny mail → deny-all NetworkPolicy

## Story

Automators create **only** an empty **`Namespace`** with a workflow survey parameter, wait on a gate that triggers **`email-plugin`**, approve from **mail**, then have automation apply a **deny‑all `NetworkPolicy`** inside that tenant namespace.

## Prerequisites

- **`openshift-bom-target`** credential on **Default** (cluster API bearer) with **`create/update Namespace`** + **`Networking`** RBAC scoped (or elevated lab admin).
- **`email-plugin`** with Gmail **`SMTP_PASSWORD`**, webhook registered for **`email-e2e-ns-netpol`** (**`scripts/register-webhook-email-e2e-ns-netpol.sh`**).
- Git content on **`origin/main`** (Tower project **AAP Demo (GitHub)** sync).
- **`oc apply -k aap-yamls/tower/`** so resources exist: **`email-e2e-create-namespace`**, **`email-e2e-apply-netpol`**, workflow **`email-e2e-ns-netpol`**.

## Instructions (Automation Controller UI)

1. **Projects → AAP Demo (GitHub) → Sync** (until playbooks referenced by new templates are present).

2. **Templates → Workflow Templates → `email-e2e-ns-netpol` → Launch**.

3. Survey **Target namespace name** — use a fresh name unless you reused an existing namespace (**default `email-e2e-demo`** is fine once; change if it already exists and you want repeat runs).

4. Watch **Jobs**: **`email-e2e-create-namespace`** must finish **successful**; workflow pauses on **`bom-approve-before-vms`**.

5. **Email:** open **`[AAP …] Approve …`** mail → **Approve** (or deny to stop before NetworkPolicy).

6. After approve: **`email-e2e-apply-netpol`** runs; **`NetworkPolicy`** **`email-e2e-deny-all`** appears in **`target_namespace`**.

### Verify cluster (optional)

```bash
kubectl get ns TARGET
kubectl get networkpolicy email-e2e-deny-all -n TARGET -o yaml
```

## Scripts (presenter)

Apply Tower CRs and register webhook (after **`email-plugin` Route exists):

```bash
oc apply -k aap-yamls/tower/
bash scripts/register-webhook-email-e2e-ns-netpol.sh
```

## Success criteria

- Namespace created with **`app.kubernetes.io/managed-by: aap-email-e2e`** label.
- Mail received with **Approve / Deny** while gate pending.
- After **Approve**, deny‑all **`NetworkPolicy`** exists in **`target_namespace`**.
- Workflow **Successful** overall.

## Rollback / cleanup

```bash
kubectl delete networkpolicy/email-e2e-deny-all -n TARGET --ignore-not-found
kubectl delete namespace/TARGET --ignore-not-found
```

## Git paths

| Path | Meaning |
|------|---------|
| `playbooks/email_e2e_create_namespace.yml` | Create Namespace |
| `playbooks/email_e2e_apply_netpol.yml` | Deny‑all NetworkPolicy |
| `aap-yamls/tower/jobtemplate-email-e2e-create-namespace.yaml` | Job template **`email-e2e-create-namespace`** |
| `aap-yamls/tower/jobtemplate-email-e2e-apply-netpol.yaml` | Job template **`email-e2e-apply-netpol`** |
| `aap-yamls/tower/workflowtemplate-email-e2e-ns-netpol.yaml` | Workflow **`email-e2e-ns-netpol`** + survey |
| `scripts/register-webhook-email-e2e-ns-netpol.sh` | Register **`email-plugin`** webhook for this workflow |

## Related

- UC-06 email approval pattern: [`UC-06-approve-by-email-buttons.md`](UC-06-approve-by-email-buttons.md)
- Consolidated runbook: [`../CLIENT_RUNBOOK.md`](../CLIENT_RUNBOOK.md)
