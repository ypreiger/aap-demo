# Git → EDA envelope + SCM sync + gated workflow launcher

Ingress path: **`POST /v1/github`** (expects GitHub **`push`** JSON).

Flow:

1. Classify changed paths under **`projects/*/bom`** vs **`projects/*/domain`** (`app/classify.py`).
2. **Optional:** `POST EDA_WEBHOOK_URL` with `ansible_eda_event` envelope (EDA `/ Activations`).
3. **POST** Automation Controller SCM **project sync** (`/api/v2/projects/{id}/update/`).
4. **Launch** workflow **`GIT_WORKFLOW_TEMPLATE_NAME`** (**`workshop-projects-git-driven`** by default) supplying `domains_by_project` + `git_changed_files` (+ `git_triggered`).
5. **Approval** (**`bom-approve-before-vms`**) executes before **workshop-git-push-dispatcher** — reuse existing Controller approval mail/webhook integrations.

Granularity:

| Git diff | Dispatcher markers |
|---------|---------------------|
| `projects/X/bom/namespace*.yaml`, `*-sa*.yaml` | `openshift_ns_bootstrap` (foundation only) |
| `projects/X/bom/*networkpolicy*.yaml` | `openshift_netpol_audit` (+ foundation + audit playbook) |
| other `bom/**` | `openshift_virt` (foundation + VMs + audit) |
| `projects/X/domain/firewall*` | `domain_firewall` |
| …/f5* | `domain_f5` |
| …/bluecoat* | `domain_bluecoat` |
| …/vmware* | `domain_vmware` |

## Deploy / configure

From repo root (**`ypreiger/aap-demo`**):

```bash
bash workshop/git-webhook-bridge/scripts/deploy-git-webhook-bridge.sh
# Optionally:
# EDA_WEBHOOK_URL=https://demo-aap-eda…/whatever/your_activation_exposes … GITHUB_WEBHOOK_SECRET='…'
```

Expose GitHub/GitLab repository webhook targeting `https://<route>/v1/github`.
