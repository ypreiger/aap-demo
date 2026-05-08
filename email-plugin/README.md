# email-plugin — Gmail approvals for Automation Controller (OpenShift pod)

Runs in **namespace `aap`** beside Automation Controller:

1. **`POST /v1/hooks/controller`** — Automation Controller sends a webhook when a Workflow **approval** gates (you register a webhook notification template for **Approval** on your Workflow Job Template, e.g. `bom-project-deploy`).
2. The plugin resolves the **workflow approval job**, signs short-lived URLs, sends **HTML mail** via **SMTP** (prepared for **Gmail**: `smtp.gmail.com:587` + STARTTLS).
3. The recipient taps **Approve** or **Deny** in the mail; the browser hits this Route; the plugin calls **Controller REST** (`/api/v2/workflow_approval_jobs/{id}/approve|deny/`).

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

On **AAP 4.7+**, webhook notification **`messages.workflow_approval`** is a nested object (not a string). The playbook stores JSON under **`running.body`** — the phase when an approval is **waiting**. Only template variables that exist in the Controller approval context pass validation; **`summary_fields.workflow_job`** is **rejected** for webhook types.

**Default body (Controller 27.x / AAP 2.8-style):** `{{ job.id }}` in this context is the **parent workflow job** id, not the **`workflow_approvals/{id}`** row. The plugin finds the pending approval node from that id:

```json
{"workflow_job_id": {{ job.id }}}
```

If your older Tower build truly passes the **approval** id as `job.id`, override **`wf_approve_body_template`** with `{"approval_job_id": {{ job.id }}}` when running the playbook (see `extras/register-webhook.example.yml`).

## Signed approve/deny URLs

|`Secret` keys | Meaning |
|---|---|
| **`SIGNING_SECRET`** | HMAC key for **`itsdangerous`** signed tokens embedded in approve/deny links. Rotate by restarting the Deployment after patching the Secret. |
| **`WEBHOOK_HMAC_SECRET`** (optional) | If non-empty, inbound webhooks **must** include header **`X-Email-Plugin-Signature: sha256=<hex_hmac_sha256(secret, raw_body)>`**. |
| **`EMAIL_SUBJECT_PREFIX`** (ConfigMap) | Overrides default **`[AAP]`** in approval mail subjects (**`[AAP Workshop]`** in `openshift/configmap.yaml`). |

Tokens expire after **`TOKEN_MAX_AGE_HOURS`** (default **72**).

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

## Repo layout

| Path | Purpose |
|------|--------|
| `app/` | FastAPI service |
| `openshift/` | Kustomize (BuildConfig binary, Deploy, Route, Service, CM) |
| `playbooks/register_controller_webhook_notification.yml` | Controller registration |
| `scripts/deploy-email-plugin.sh` | One-shot cluster deploy |
