# Demo runbook — Temporary ACS policy exceptions (~20 minutes)

Read this before presenting. Per-use-case notes: [use-cases.md](use-cases.md).

## Logins (do not mix these)

| Who | Where | Username | Password |
|-----|--------|----------|----------|
| Requester | Self-service portal **or** AAP gateway | `alice` | `AAP_USER_ALICE_PASSWORD` in `.env` |
| Approver | **AAP gateway only** | `sre-approver` | `AAP_USER_SRE_PASSWORD` in `.env` |
| Cluster admin | `oc` / ACS UI | cluster `admin` | not an AAP persona |

These are **AAP local users**, not the OpenShift IdP (`rhbk`). Signing in to the portal or gateway with OpenShift SSO will not be alice/sre-approver.

Portal: https://aap-portal-rhaap-portal-aap.apps.ocp.7hrxw.sandbox880.opentlc.com/  
AAP gateway: https://demo-aap-aap.apps.ocp.7hrxw.sandbox880.opentlc.com  
Approvals (SRE): https://demo-aap-aap.apps.ocp.7hrxw.sandbox880.opentlc.com/#/workflow_approvals  
ACS Central: https://central-acs.apps.ocp.7hrxw.sandbox880.opentlc.com  

The portal **Create Task** list is job templates only. Item **Temporary ACS Policy Exception** launches workflow `WF-Temporary-ACS-Policy-Exception` and returns immediately. SRE never approves in the portal.

## Pre-demo (workstation, cluster-admin)

```bash
cd acs-exceptions
set -a && source .env && set +a
python3 scripts/preflight-demo.py
```

If preflight fails: `ansible-playbook playbooks/setup-demo-fixtures.yml` then `python3 scripts/aap-config-apply.py`, then preflight again. Optional clean slate: `ansible-playbook playbooks/demo-reset.yml`.

Form rules that have already bitten this demo:

- Justification **at least 10 characters** (`i want it` is 9 and is rejected).
- Happy-path namespace is **`demo-app`** (alice is Admin there). `demo-restricted` is the deny/blast-radius namespace.
- First job after a Git push may spend ~1 minute on SCM update. Later jobs in the same 5 minutes reuse the cache.

## Act 0 (2 min) — the problem

1. ACS → Policy **Kubernetes Actions: Exec into Pod** → enforcement includes `FAIL_KUBE_REQUEST_ENFORCEMENT`.
2. `oc get -n demo-app deploy/nginx` — sleep pod (named nginx).
3. `oc exec -n demo-app deploy/nginx -- date` is **blocked** by webhook `k8sevents.stackrox.io`.

## Act 1 (8 min) — UC-4 terminal access

1. Portal as **alice** → **Create Task** → **Temporary ACS Policy Exception**.
2. Namespace `demo-app`, policy **Kubernetes Actions: Exec into Pod**, duration **5**, justification ≥10 chars, optional ticket.
3. The portal job succeeds in about a minute and prints a workflow job id. It does **not** wait for SRE.
4. As **sre-approver**, open **AAP Approvals** (`#/workflow_approvals`). Approve **Approval-Node-SRE**. Extra vars on the workflow job include namespace, policy, duration, justification.
5. ACS exclusions show `AAPEX-<date>-<hex> demo-app`. Scope is **empty `cluster` + namespace `demo-app`** (ACS 4.11 kube-event matching). Do not expect `cluster: ocp-sandbox880`.
6. `oc exec -n demo-app deploy/nginx -- date` **succeeds**. `oc exec -n demo-restricted deploy/nginx -- date` stays **blocked**.
7. Controller → Schedules → `AAPEX-rollback-<request_id>` (one-shot, not a sleeping job). After ~5 minutes JT-03 removes only that exclusion; exec is blocked again.
8. Audit: AAP job output of JT-02/JT-05 prints the JSON. Optional: `oc get cm -n aap-demo -l aapex=audit`. Git `audit/` files are **not** the live store unless `GIT_TOKEN` is set.

Optional negative: as **bob**, same form for `demo-app` → JT-01 fails before approval (`rejected_rbac`).

## Act 2 (optional, 4 min) — UC-5 privileged container

On this cluster, ACS admission for a raw privileged Pod is **not reliably denying** (PSS may only warn). Prefer UC-4 as the live block/unblock proof. If you still show UC-5: `oc apply -f demo/privileged-deploy.yaml`, then the same request with policy **Privileged Container**.

## Act 3 (3 min) — safety

1. **carol** + `demo-app` → `No namespaces with Admin permissions were found. An ACS policy exception request cannot be opened.`
2. `ansible-playbook playbooks/verify-guardrails.yml` — non-allowlisted policy refused.
3. JT-06 every 5 minutes removes **expired** `AAPEX-*` exclusions only (uses the `expiration` field). It does not delete live windows.

## Act 4 (2 min) — notifications

`audit/notifications.log` is written **inside the job workspace**. Show it in the JT-01/JT-02 job output / artifacts. SMTP is not configured (`SMTP_HOST` unset).

## Reset

```bash
ansible-playbook playbooks/demo-reset.yml
```

Strips `AAPEX-*` exclusions only. Does not delete ACS policies.
