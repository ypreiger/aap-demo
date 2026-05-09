# UC-06 — Approve (or deny) a workflow gate from email (**Approve / Deny** buttons)

## Goal

Approve or deny a paused workflow from the **email** message (**Approve** / **Deny** links). Requires **`email-plugin`** and a **Webhook** notification on the workflow template you launch.

---

## Prerequisites (one-time per environment)

| # | Task | Detail |
|---|------|--------|
| 1 | **`email-plugin` deployed** in **`namespace: aap`** | README: **`../../email-plugin/README.md`**. SMTP enabled, e.g. `SMTP_PASSWORD='…' DISABLE_SMTP=false ../../email-plugin/scripts/deploy-email-plugin.sh`. |
| 2 | **Controller Base URL set** | **Administration → Settings → System** — **Base URL of the service** is the live Controller HTTPS prefix. |
| 3 | **Webhook notification registered** matching **your demo workflow** | Playbook **`../../email-plugin/playbooks/register_controller_webhook_notification.yml`**. Defaults attach to **`bom-project-deploy`** only. |
| 4 | **(Optional)** Mail also for **`workshop-multi-domain`** | Second playbook run — see **`../../documentation/06_EMAIL_APPROVAL.md`** §4 (*Other workflow job templates*). |

**Without steps 1–3, no mail arrives** — use **Success criteria (negative)** below.

---

## Path A — Approve via email (**recommended**, matches default webhook)

The stock registration playbook links the webhook to workflow template **`bom-project-deploy`**.

### Instructions

1. Log in to **Automation Controller** (gateway → Controller).
2. Open **Templates** → **Workflow Templates**.
3. Open **`bom-project-deploy`** → **Launch** (Rocket icon).
4. Complete the survey (at minimum set **`project_name`**, e.g. **`proj1`**; defaults for VM sizing usually work as a demo).
5. Open **Jobs** → select the newest **workflow job** → watch the graph.
6. Wait until the flow stops on **`bom-approve-before-vms`** (status **Waiting for approval / Pending**, depending on version).
7. Check the **approver mailbox** tied to SMTP / **`DEFAULT_TO_EMAIL`** (**`email-plugin`** `ConfigMap`) — inbox and **spam**.
8. Open the email; click **`Approve`** to continue to **`bom-project-vms`** or **`Deny`** to stop without VM provisioning.
9. Return to Controller **Jobs** — the workflow resumes or fails according to your choice **without** touching **Approve** inside the Controller UI **if** SMTP + webhook work.

### What you should see

| Step | Evidence |
|------|----------|
| Email received | Subject often prefixed (**`EMAIL_SUBJECT_PREFIX`** / `[AAP Workshop]`). Body contains workflow context + buttons. |
| Approve tapped | Browser hits **`email-plugin` Route**, then **`201`/`200`** REST on Controller approval API; workflow graph advances to **`bom-project-vms`**. |
| Deny tapped | Workflow ends / stops without VM creation (expected). |

### Success criteria — Path A

- Email arrives within a few minutes of the approval node becoming active.
- **Approve** progresses the **`bom-project-deploy`** graph past **`bom-approve-before-vms`**.

---

## Path B — Same mail / buttons for **`workshop-multi-domain`**

Default playbook **`workflow_name=bom-project-deploy`**. **`workshop-multi-domain`** uses the **same approval template name** (**`bom-approve-before-vms`**) **but another workflow job template** — register again:

```bash
EP="$(oc get route email-plugin -n aap -o jsonpath='{.spec.host}')"
WH="https://${EP}/v1/hooks/controller"
CH="$(oc get secret aap-controller-api -n aap -o jsonpath='{.data.host}' | base64 -d)"
TK="$(oc get secret aap-controller-api -n aap -o jsonpath='{.data.token}' | base64 -d)"

ansible-playbook ../../email-plugin/playbooks/register_controller_webhook_notification.yml \
  -e controller_host="$CH" \
  -e controller_oauth_token="$TK" \
  -e webhook_target_url="$WH" \
  -e workflow_name=workshop-multi-domain \
  -e notification_name=workshop-email-plugin-webhook
```

Then repeat **Instructions** but launch **`workshop-multi-domain`** (survey **`workshop_mock_base_url`** still required).

---

## Fallback — approve in Controller UI (no dependency on mail)

Works even when SMTP is offline:

1. **Jobs** → open the paused **workflow job**.
2. Open the pending **approval** step.
3. Click **Approve** or **Deny**.

---

## Success criteria — negative / demo without plugin

If **`email-plugin` is intentionally not deployed**: use **fallback** approval in the UI above; **`UC-06` mail-specific success criteria do not apply**.

---

## Troubleshooting

| Symptom | Hint |
|---------|------|
| No mail | **`DISABLE_SMTP`**, empty **`SMTP_PASSWORD`** (Gmail **App Password** in **`Secret/email-plugin-secrets`**), egress block, **`email-plugin`** pod CrashLoop, wrong **`DEFAULT_TO_EMAIL`**, webhook not associated with **your** WFJT. |
| Notification **Webhook 422** | Body must carry **`workflow_job_id`** from **`{{ job.id }}`** (parent workflow job) on modern Controller — re-run **`register_controller_webhook_notification.yml`** defaults; **`email-plugin/README.md`**. |
| Mail but buttons 401/403/400 | Signing secret **`SIGNING_SECRET`**, token expiry (**`TOKEN_MAX_AGE_HOURS`**), stale Deployment after Secret edits. **`../../documentation/06_EMAIL_APPROVAL.md`** table. |
| Works for **`bom`** but not **workshop** | Run **Path B** registration snippet. |

## Related docs

- **`../../documentation/06_EMAIL_APPROVAL.md`**
- **`../../email-plugin/README.md`**
- Full narrative order: **`../CLIENT_RUNBOOK.md`** §5 (email) and §6 (`workshop-multi-domain`).
