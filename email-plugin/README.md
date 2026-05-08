# email-plugin — Gmail approvals for Automation Controller (OpenShift pod)

Runs in **namespace `aap`** beside Automation Controller:

1. **`POST /v1/hooks/controller`** — Automation Controller sends a webhook when a Workflow **approval** gates (you register a webhook notification template for **Approval** on your Workflow Job Template, e.g. `bom-project-deploy`).
2. The plugin resolves the **workflow approval job**, signs short-lived URLs, sends **HTML mail** via **SMTP** (prepared for **Gmail**: `smtp.gmail.com:587` + STARTTLS).
3. The recipient taps **Approve** or **Deny** in the mail; the browser hits this Route; the plugin calls **Controller REST** (`/api/v2/workflow_approval_jobs/{id}/approve|deny/`).

**Workshop / Controller wiring** (webhook body, extra workflows, troubleshooting): **[`../documentation/EMAIL_APPROVAL.md`](../documentation/EMAIL_APPROVAL.md)**.

**EDA**: not required — Controller notifies this pod directly via webhook HTTP. Optionally, an EDA source could relay the same JSON to this URL.

## Prerequisites

| Item | Notes |
|------|--------|
| **`Secret/aap-controller-api`** | Existing demo secret supplying Controller HTTPS host & OAuth token reused for `CONTROLLER_*` patching. |
| **Gmail** | Generate an **[App Password](https://support.google.com/accounts/answer/185833)** (2FA-enabled Google account); put into `SMTP_PASSWORD`. |
| **Cluster egress** | Allow pod → `smtp.gmail.com:587` and HTTPS to your Automation Controller Route. Dockerfile **binary builds** also need the cluster to pull the OpenShift **`docker`/builder runtime** image (normally via **registry.redhat.io** / **Quay.io**); blocked registries manifest as **`502`** / **`ImagePullBackOff`** on **`email-plugin-N-build`** — fix cluster mirroring/firewall first. |

## Deploy (quick)

From the **`aap-demo`** repository root ([`ypreiger/aap-demo`](https://github.com/ypreiger/aap-demo)), after `oc login`:

```bash
./email-plugin/scripts/deploy-email-plugin.sh
```

Creates `Secret/email-plugin-secrets`, builds **`BuildConfig/email-plugin`** binary from `email-plugin/`, rolls out **`Deployment/email-plugin`**, patches **`PUBLIC_BASE_URL`** from **`Route/email-plugin`** and **`CONTROLLER_HOST`** from **`Secret/aap-controller-api`**.

**Long builds / flaky registries:** the script uploads sources then **`oc wait`s up to `BUILD_WAIT_SECONDS` (default **2700**) for phase **Complete**. Override if your builder image pulls slowly: `BUILD_WAIT_SECONDS=5400 ./email-plugin/scripts/deploy-email-plugin.sh`.

**Enable real Gmail sending:**

```bash
SMTP_PASSWORD='<gmail-app-password>' DISABLE_SMTP=false ./email-plugin/scripts/deploy-email-plugin.sh
```

`DEFAULT_TO_EMAIL` (default `yaakovpreiger@gmail.com`) and SMTP identity live in **`ConfigMap/email-plugin-env`** (`openshift/configmap.yaml`).

## Register the Controller webhook (+ approval JSON body example)

Pick the HTTPS base printed by `deploy-email-plugin.sh` (e.g. `https://email-plugin-aap.apps...`).

```bash
WH="https://${ROUTE_HOST}/v1/hooks/controller"

ansible-playbook email-plugin/playbooks/register_controller_webhook_notification.yml \
  -e controller_host="$(oc get secret aap-controller-api -n aap -o jsonpath='{.data.host}' | base64 -d)" \
  -e controller_oauth_token="$(oc get secret aap-controller-api -n aap -o jsonpath='{.data.token}' | base64 -d)" \
  -e webhook_target_url="$WH"
```

On **AAP 4.7+**, webhook notification **`messages.workflow_approval`** is a nested object (not a string). The playbook stores JSON under **`running.body`** — the phase when an approval is **waiting**. The Controller **workflow approval** Jinja context includes **`workflow_url`** but **not** **`job`** (see upstream AWX `WorkflowApproval.context`). Using `{{ job.id }}` fails silently and AWX POSTs **`{}`**.

**Default body:** pass the workflow UI URL; **email-plugin** extracts **`workflow_job_id`** from it and resolves the pending **`approval_job_id`** via the Controller API:

```json
{"workflow_url": {{ workflow_url | tojson }}}
```

If you must override (legacy builds), set **`wf_approve_body_template`** when running the playbook (see `extras/register-webhook.example.yml`).

## Signed approve/deny URLs

|`Secret` keys | Meaning |
|---|---|
| **`SIGNING_SECRET`** | HMAC key for **`itsdangerous`** signed tokens embedded in approve/deny links. Rotate by restarting the Deployment after patching the Secret. |
| **`WEBHOOK_HMAC_SECRET`** (optional) | If non-empty, inbound webhooks **must** include header **`X-Email-Plugin-Signature: sha256=<hex_hmac_sha256(secret, raw_body)>`**. |
| **`EMAIL_SUBJECT_PREFIX`** (ConfigMap) | Overrides default **`[AAP]`** in approval mail subjects (**`[AAP Workshop]`** in `openshift/configmap.yaml`). |

Tokens expire after **`TOKEN_MAX_AGE_HOURS`** (default **72**).

### Preview the approval email (same HTML as runtime)

Without SMTP credentials you can render the HTML body locally:

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)/email-plugin"
python3 scripts/send_sample_approval_email.py --print-html > /tmp/sample-approval-mail.html
# Open /tmp/sample-approval-mail.html in a browser.

# Or send yourself one message (Gmail App Password):
SMTP_USER='your@gmail.com' SMTP_PASSWORD='<app-password>' \\
  MAIL_FROM='your@gmail.com' DEFAULT_TO_EMAIL='your@gmail.com' \\
  python3 scripts/send_sample_approval_email.py
```

### Security reminders

Links are GET requests (email clients require navigable anchors). Tokens are signed and expiry-limited — treat links like capability URLs. Prefer TLS on the **`Route`** and least-privilege **Controller OAuth scopes** dedicated to approving workflows.

### Alternative recipient per launch

Webhook JSON supports optional **`to_email`** or **`recipient`** key if your notification template renders it alongside the snippet above:

```json
{"approval_job_id": {{ job.id }}, "workflow_job_id": {{ job.summary_fields.workflow_job.id }}, "to_email": "ops@example.com"}
```

Otherwise the **`DEFAULT_TO_EMAIL`** env is used.

## Troubleshooting

- **Build **`email-plugin-N`** canceled at ~300s without logs** → use the current **`deploy-email-plugin.sh`** (split **`oc wait`**) or bump **`BUILD_WAIT_SECONDS`** — older **`oc start-build --follow --wait`** can time out early.
- **Build pod **`ImagePullBackOff`** on **`quay.io/openshift-release-dev/ocp-v4.0-art-dev@…`** (`502 Bad Gateway`)** → temporary registry outage or blocked egress from nodes; retry later or mirror builder images — the app **`Containerfile`** is **`registry.access.redhat.com/ubi9/python-312`** but the cluster still needs its **Docker/build strategy helper** image.
- **Deployment **`manifest unknown`** for **`…/email-plugin:latest`** → no successful push yet from the Build; fix Build as above then **`oc start-build`** again.

- **`503` webhook** → `CONTROLLER_HOST`/`CONTROLLER_TOKEN` missing.
- **`401` webhook** → HMAC mismatch; clear `WEBHOOK_HMAC_SECRET` or fix Controller headers.
- **No mail but hook returns `{ok:true}`** → `DISABLE_SMTP=true` or empty `SMTP_PASSWORD`; check **`email-plugin`** pod logs (`kubectl logs deploy/email-plugin -n aap`).
- **`422` webhook** → cannot resolve approvals; workflow may not yet be paused on an approval gate, or webhook JSON lacks ids (customize **`wf_approve_body_template`**).
- **“Open in Controller” lands on API / SSO error** → Controller often exposes **`/api`** in **`CONTROLLER_HOST`**, but users must open the SPA through the gateway or trimmed host. Patch **`CONTROLLER_UI_PUBLIC_URL`** (**`CONTROLLER_WORKFLOW_JOB_UI_PATH_TEMPLATE`** optional) on **`email-plugin-env`** — see **[`documentation/EMAIL_APPROVAL.md`](../documentation/EMAIL_APPROVAL.md)** (*Open in Controller link* subsection).

## Repo layout

| Path | Purpose |
|------|--------|
| `app/` | FastAPI service |
| `openshift/` | Kustomize (BuildConfig binary, Deploy, Route, Service, CM) |
| `playbooks/register_controller_webhook_notification.yml` | Controller registration |
| `scripts/deploy-email-plugin.sh` | One-shot cluster deploy |
