# UC-07 — Email E2E: create Namespace → Approve/Deny mail → deny-all NetworkPolicy

## Goal

Create an empty **`Namespace`** from survey input, stop at approval (**`email-plugin`** mail), **Approve** from email, then apply a **deny‑all `NetworkPolicy`** in that namespace.

## Prerequisites

- **`openshift-bom-target`** credential on **Default** (cluster API bearer) with **`create/update Namespace`** + **`Networking`** RBAC scoped (or elevated lab admin).
- **`email-plugin`** with Gmail **`SMTP_PASSWORD`**, webhook registered for **`email-e2e-ns-netpol`** (**`scripts/register-webhook-email-e2e-ns-netpol.sh`**).
- Git content on **`origin/main`** (Tower project **AAP Demo (GitHub)** sync).
- **`oc apply -k aap-yamls/tower/`** so resources exist: **`email-e2e-create-namespace`**, **`email-e2e-apply-netpol`**, workflow **`email-e2e-ns-netpol`**.

**Tower operator caveat:** If **`oc describe jobtemplate … / workflowtemplate …`** in namespace **`aap`** shows **`There was an error in the job/workflow template`** (often right after the playbooks first land in Git), Controller may still lack the **Job Templates** or the **Workflow Visualizer** may be **empty**. Sync the project once, then run **`scripts/bootstrap-email-e2e-controller-api.sh`** (idempotent) — the launch script **`scripts/run-email-e2e-ns-netpol-workflow.sh`** calls it automatically after project sync.

**Name mix-up:** In the UI search for **`email-e2e-ns-netpol`** (Workflow Job Template name). **`email-e2e-demo`** is only the **default survey answer** (**Target namespace**), not the workflow template.

## Instructions (Automation Controller UI)

1. **Projects → AAP Demo (GitHub) → Sync** (until playbooks referenced by new templates are present).

2. **Templates → Workflow Templates** → select **`email-e2e-ns-netpol`** → **Visualizer**: expect **three** nodes (create namespace → approval → NetworkPolicy). If the graph is blank, run **`bootstrap-email-e2e-controller-api.sh`**, hard-refresh the tab, reopen the workflow.

3. Click **Launch** on **`email-e2e-ns-netpol`** (or run **`scripts/run-email-e2e-ns-netpol-workflow.sh`** from a shell).

4. Survey **Target namespace name** — use a fresh name unless you reused an existing namespace (**default `email-e2e-demo`** is fine once; change if it already exists and you want repeat runs).

5. Watch **Jobs**: **`email-e2e-create-namespace`** must finish **successful**; workflow pauses on **`bom-approve-before-vms`**.

6. **Email:** open **`[AAP …] Approve …`** mail → **Approve** (or deny to stop before NetworkPolicy).

7. After approve: **`email-e2e-apply-netpol`** runs; **`NetworkPolicy`** **`email-e2e-deny-all`** appears in **`target_namespace`**.

### Verify cluster (optional)

```bash
kubectl get ns TARGET
kubectl get networkpolicy email-e2e-deny-all -n TARGET -o yaml
```

## Scripts

Apply Tower CRs and register webhook (after **`email-plugin` Route exists):

```bash
oc apply -k aap-yamls/tower/
bash scripts/register-webhook-email-e2e-ns-netpol.sh
```

Launch from the cluster ( **`oc login`**, **`Secret/aap-controller-api`** in **`aap`**) — API sync + **`AUTO_APPROVE=true`** skips waiting for mail (use **`false`** to exercise email approval):

```bash
./scripts/run-email-e2e-ns-netpol-workflow.sh
AUTO_APPROVE=false TARGET_NAMESPACE=my-demo-ns ./scripts/run-email-e2e-ns-netpol-workflow.sh
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
