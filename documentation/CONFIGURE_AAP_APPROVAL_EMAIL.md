# BOM workflow approvals with email-plugin (recommended) or Controller SMTP

Two supported patterns:

1. **`email-plugin` (recommended)** — a small HTTPS service deployed in **`aap`** (see **[`email-plugin/README.md`](../email-plugin/README.md)**). Automation Controller emits a **webhook on Workflow Approval** → the pod sends Gmail (or compatible SMTP) with **signed Approve / Deny buttons** → clicking calls Controller REST to finish the waiting approval task.  
   Defaults: **`DEFAULT_TO_EMAIL=yaakovpreiger@gmail.com`** (ConfigMap env in the plugin manifest); override per message with optional JSON keys `to_email` / `recipient` if you customize the webhook body.

2. **Native Controller email notification** — built-in SMTP template on Workflow **Approval** (no clickable REST bridge; relies on Notification template copy + Controller base URL). Use when you cannot run the pod.

References: [Red Hat — Notifications](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.4/html/automation_controller_user_guide/controller-notifications) (approval events beside Start/Success/Failure).

## Path A — `email-plugin` (Gmail SMTP + clickable Approve/Deny)

### Controller settings

Under **Administration → Settings → System** (“Miscellaneous”), set **Base URL of the service** to your real Automation Controller HTTPS URL so links rendered by Controller stay correct.

### Deploy the plugin (this repo)

```bash
# After oc login targeting the cluster hosting AAP (from your clone of aap-demo)
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SMTP_PASSWORD='<gmail-app-password>' DISABLE_SMTP=false ./email-plugin/scripts/deploy-email-plugin.sh
```

The script reapplies manifests from `email-plugin/openshift/`, patches **`CONTROLLER_HOST`** from **`Secret/aap-controller-api`**, runs an OpenShift Source **binary Docker build**, and sets **`PUBLIC_BASE_URL`** from **`Route/email-plugin`**.

### **`Open in Controller` link looks wrong**

The mail footer uses a **browser** URL resolved from Automation Controller **`related.web_url` / `jobs_web_url`** when those look sane. If the API only exposes REST paths (or SSO expects the **gateway** host), synthesize links with ConfigMap **`email-plugin-env`**:

| Env | Meaning |
|-----|----------|
| **`CONTROLLER_UI_PUBLIC_URL`** | HTTPS prefix you see in the address bar **before** the `#…` fragment when Jobs → workflow job is open (often the **gateway** route + `/…/automation-controller`, not necessarily the **`aap-controller-api` host** string). Optional. |
| **`CONTROLLER_WORKFLOW_JOB_UI_PATH_TEMPLATE`** | Fragment path appended to that prefix. Default **`/#/jobs/workflow/{workflow_job_id}`**. If your build uses another Jobs path per product docs, substitute it (`{workflow_job_id}` stays available). |

If unset, **`email-plugin`** falls back to **`CONTROLLER_HOST`** with a trailing **`/api`** stripped, then **`/#/jobs/workflow/{id}`** — sufficient for standalone Controller routes.

```bash
oc patch configmap/email-plugin-env -n aap --type merge -p '{
  "data": {
    "CONTROLLER_UI_PUBLIC_URL": "https://<YOUR-GATEWAY-OR-STANDALONE-ORIGIN>/<optional-automation-controller-subpath>",
    "CONTROLLER_WORKFLOW_JOB_UI_PATH_TEMPLATE": "/#/jobs/workflow/{workflow_job_id}"
  }
}'
oc rollout restart deployment/email-plugin -n aap
```

### Register the webhook on `bom-project-deploy`

```bash
EP=$(oc get route email-plugin -n aap -o jsonpath='{.spec.host}')
WH="https://${EP}/v1/hooks/controller"
CH="$(oc get secret aap-controller-api -n aap -o jsonpath='{.data.host}' | base64 -d)"
TK="$(oc get secret aap-controller-api -n aap -o jsonpath='{.data.token}' | base64 -d)"

ansible-playbook email-plugin/playbooks/register_controller_webhook_notification.yml \
  -e controller_host="$CH" \
  -e controller_oauth_token="$TK" \
  -e webhook_target_url="$WH"
```

This creates notification **`bom-email-plugin-webhook`** and associates it with workflow **`bom-project-deploy`** approvals. Default webhook body uses **`workflow_url`** (Controller workflow-approval context — see **`email-plugin/README.md`**). **`email-plugin`** resolves **`workflow_job_id`** and the pending **`workflow_approvals/{id}`** via the Controller API.

### Same webhook for **`email-e2e-ns-netpol`** (UC-07)

Uses the **same** approval unified template (**`bom-approve-before-vms`**) as **`bom-project-deploy`**, but it is another **workflow job template** — Controller only fires webhooks tied to **that** template. Register once:

```bash
bash scripts/register-webhook-email-e2e-ns-netpol.sh
```

From repo root (`aap-demo`), with **`email-plugin`** Route up and **`Secret/aap-controller-api`** valid. Equivalent manual **`ansible-playbook`**: **`workflow_name=email-e2e-ns-netpol`**, **`notification_name=email-e2e-email-plugin-webhook`**. See **`workshop/use-cases/UC-07-email-e2e-namespace-netpol.md`**.

### Same webhook for **`workshop-multi-domain`**

The playbook’s default **`workflow_name`** is **`bom-project-deploy`**. The multi-domain workflow (**`workshop-multi-domain`**) uses the **same** approval template (**`bom-approve-before-vms`**) but is a **different** workflow job template, so Controller does **not** automatically reuse the webhook. Run registration again:

```bash
ansible-playbook email-plugin/playbooks/register_controller_webhook_notification.yml \
  -e controller_host="$CH" \
  -e controller_oauth_token="$TK" \
  -e webhook_target_url="$WH" \
  -e workflow_name=workshop-multi-domain \
  -e notification_name=workshop-email-plugin-webhook
```

Hands-on launcher steps for both workflows: **`workshop/CLIENT_RUNBOOK.md`** §5–6. End-to-end diagrams (mail + optional EDA): **[`documentation/EMAIL_APPROVAL_EDA_END_TO_END.md`](documentation/EMAIL_APPROVAL_EDA_END_TO_END.md)**.

### Gmail specifics

Use **SMTP App Password**, not your normal password. Populate **`Secret/email-plugin-secrets`** key **`SMTP_PASSWORD`** (deploy script forwards `SMTP_PASSWORD=...`). TLS stays enabled on **`smtp.gmail.com:587`**.

### Optional inbound HMAC (`WEBHOOK_HMAC_SECRET`)

If you set **`WEBHOOK_HMAC_SECRET`** in the Secret, configure the webhook template’s **Additional headers** (`headers` dict) **or** a reverse proxy — the plugin verifies:

```
X-Email-Plugin-Signature: sha256=<hex_hmac_sha256(secret, raw_body)>
```

### Troubleshooting (`email-plugin`)

| Symptom | Action |
|---------|--------|
| Gmail auth errors | Rotate App Password; confirm `SMTP_USER` matches Gmail account owning the App Password |
| Buttons 400/401 | Signing secret mismatch / expired token (`TOKEN_MAX_AGE_HOURS`); restart Deployment after patching Secret |
| Webhook JSON parse errors | Controller version may render different fields — override **`wf_approve_body_template`** in the registration playbook extras |
| **Open in Controller** 404 / wrong host / SSO loop | Patch **`CONTROLLER_UI_PUBLIC_URL`** + optional **`CONTROLLER_WORKFLOW_JOB_UI_PATH_TEMPLATE`** (subsection *Open in Controller link* above); restart **`email-plugin`**. |
| Egress failures | Namespace NetworkPolicy/firewall blocking `smtp.gmail.com:587` or Controller HTTPS |

## Path B — Native Controller SMTP (no Approve buttons)

Follow the Ansible playbook path if you skip `email-plugin`.

1. Copy `extras/approval-email.vars.example.yml` → `extras/approval-email.vars.yml` (never commit SMTP secrets).

2. Run from **aap-demo** repository root:

   ```bash
   export CONTROLLER_HOST='https://<your-controller-route>'
   export CONTROLLER_TOKEN='<OAuth PAT with notification privileges>'
   ansible-playbook playbooks/controller_configure_bom_approval_email.yml \
     -e @extras/approval-email.vars.yml
   ```

The playbook associates notification **`bom-approval-email`** with workflow **`bom-project-deploy`** for **Approval** events only.
