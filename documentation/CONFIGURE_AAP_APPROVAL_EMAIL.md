# Email when a BOM workflow waits for approval

Automation Controller sends mail using **SMTP-based notification templates**. You associate one of those templates with workflow event **Approval** so approvers receive a message when **`bom-project-before-vms`** (or similar) enters *pending* state.

References: [Red Hat Ansible Automation Platform — Notifications](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.4/html/automation_controller_user_guide/controller-notifications) (events include workflow **Approval** alongside Start / Success / Failure).

## Prerequisites

1. **Controller base URL**  
   **Settings → Subscription / Miscellaneous (System)** → **Base URL of the service** → set to your real Controller HTTPS hostname.  
   Notification links and some templates use this value.

2. **Outbound SMTP** your cluster is allowed to use (corporate relay, Amazon SES, etc.).  
   Red Hat’s internal relay host and auth are **not** in this repo—use your IT-provided values.

## Option A — UI (recommended first time)

1. **Administration → Notifications** (or **Access → Notifications**, depending on AAP revision) → **Notification templates** → **Create notification template**.
2. **Organization:** `Default` (or yours). **Type:** **Email**.
3. Complete **SMTP host**, **Port**, TLS/SSL, **Username/password** if required, **Sender**, **Recipients** — include **`ypreiger@redhat.com`** (comma-separated allowed where the UI permits multiple recipients).
4. **Test notification** using the wizard’s Test button; fix SMTP until mail arrives.

5. **Automation Execution → Templates** → open workflow **`bom-project-deploy`** (`wjt-bom-project-deploy`).
6. Open the **Notifications** tab / section.
7. Under **Approval** (workflow templates with approvals expose this alongside Start/Success/Failure), **enable** or **associate** your new email notification template.

Save. Launch **`bom-project-deploy`**; after the foundation step, when approval is **pending**, you should receive mail with a link back to the job (exact body follows the default template described in Red Hat docs; you may customize optional message templates on the notification object).

## Option B — API playbook from this repo

If you prefer GitOps-friendly automation:

1. Copy `extras/approval-email.vars.example.yml` → e.g. `extras/approval-email.vars.yml` (keep **outside** Git; do **not** commit SMTP passwords).

2. Run from repository root:

   ```bash
   export CONTROLLER_HOST='https://<your-controller-route>'
   export CONTROLLER_TOKEN='<OAuth personal access token with admin or notification rights>'
   ansible-playbook playbooks/controller_configure_bom_approval_email.yml \
     -e @extras/approval-email.vars.yml
   ```

The playbook creates-or-updates notification **`bom-approval-email`** and associates it with workflow **`bom-project-deploy`** for **approval** events only.

## Troubleshooting

- No mail: verify SMTP from a **Test** in the UI; check spam; confirm pods can reach the relay (egress / NetworkPolicy).
- Link in email wrong: fix **Base URL of the service** in Controller settings.
- **403** on API: token needs rights to create notification templates and modify the workflow job template.
