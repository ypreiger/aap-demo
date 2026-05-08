# Ansible Automation Platform — `aap-demo`

## Repository layout

| Path | Contents |
|------|----------|
| **`playbooks/`** | Playbooks; **`inventory/`** hosts; **`collections/requirements.yml`** Galaxy allow list |
| **`workshop/`** | Multi-domain workflows, mock infra, E2E scripts — start at **[workshop/README.md](workshop/README.md)** and **[workshop/CLIENT_RUNBOOK.md](workshop/CLIENT_RUNBOOK.md)** |
| **`documentation/`** | **[documentation/README.md](documentation/README.md)** — Hub, Controller, collections, webhooks |
| **`aap-yamls/`** | Automation Controller / Tower Kubernetes manifests — **[aap-yamls/README.md](aap-yamls/README.md)** |
| **`projects/`** | BOM and domain YAML (`proj1`, `proj2`) — **[documentation/DOMAIN_INPUT_YAML.md](documentation/DOMAIN_INPUT_YAML.md)** |
| **`email-plugin/`** | Approval email service — **[email-plugin/README.md](email-plugin/README.md)** |

**Git-driven workflows:** **[documentation/GIT_WEBHOOK_EDA.md](documentation/GIT_WEBHOOK_EDA.md)** and **`workshop/git-webhook-bridge/`**.

**Collections and EE:** **[documentation/ANSIBLE_COLLECTIONS.md](documentation/ANSIBLE_COLLECTIONS.md)**. Verify locally: **`./scripts/verify-collections-and-ee.sh`**.

**OpenShift Virtualization / surveys:** **[documentation/VIRTUALIZATION_WORKFLOW_SURVEY.md](documentation/VIRTUALIZATION_WORKFLOW_SURVEY.md)**.

**BOM workflows** (`bom-project-deploy`, surveys): use **`project_name`** → **`aap-demo/projects/{project_name}/bom`**. Attach credential **`openshift-bom-target`** (OpenShift/Kubernetes API bearer token) to **`bom-project-foundation`** and **`bom-project-vms`**.

**Approval email:** **`email-plugin/`** + **[documentation/CONFIGURE_AAP_APPROVAL_EMAIL.md](documentation/CONFIGURE_AAP_APPROVAL_EMAIL.md)**.

**Namespace → approval email → NetworkPolicy:** workflow **`email-e2e-ns-netpol`** — **[workshop/use-cases/UC-07-email-e2e-namespace-netpol.md](workshop/use-cases/UC-07-email-e2e-namespace-netpol.md)**; apply **`oc apply -k aap-yamls/tower/`**, then **`scripts/register-webhook-email-e2e-ns-netpol.sh`**.

---

## Minimal three-playbook chain

Used as a smoke test for Workflow Job Templates passing **`set_stats`** variables:

1. **`playbooks/01_validate_environment.yml`**
2. **`playbooks/02_publish_workflow_stats.yml`**
3. **`playbooks/03_finalize.yml`**

Local run:

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ansible-playbook playbooks/01_validate_environment.yml
ansible-playbook playbooks/02_publish_workflow_stats.yml
ansible-playbook playbooks/03_finalize.yml
```

In a workflow, step 3 receives **`demo_batch_id`** from step 2. Running step 3 alone prints **`n/a`** for that variable.

---

## Automation Controller checklist

Configure objects in **Automation Controller** (UI or API). Use the names in the tables so this repository’s docs and CRs match your deployment.

### Automation Hub

Hub **`/content/collections`**:

- Sync **Community** using **[documentation/HUB_COLLECTIONS.md](documentation/HUB_COLLECTIONS.md)** and **`scripts/hub-sync-community-from-requirements.sh`**.
- Sync **Published** using an offline token — **§2** in the same file and **`scripts/hub-sync-rh-certified-from-secret.sh`**.

### Organization

Create or reuse an **Organization** (example name: **`Demo`**).

### Execution environment

**Automation Execution Environments** → **Add** → image with Ansible and ansible-runner (platform minimal EE or custom image from **`ansible-builder`**). Attach globally or per organization.

### Credentials

| Type | Use |
|------|-----|
| **Source Control** | Clone `https://github.com/ypreiger/aap-demo` |
| **Machine / SSH / Vault** | Optional; not required for `localhost` demos |

For GitHub HTTPS, use a **Personal Access Token** as the password.

### Project

**Projects** → **Add** → URL **`https://github.com/ypreiger/aap-demo`** → attach Source Control credential → save → wait until sync succeeds.

### Inventory

**Inventories** → **Add** → add host **`localhost`** with variables:

```yaml
ansible_connection: local
```

### Job templates (three)

**Templates** → **Add** → **Job template** → type **Ansible Playbook**:

| Field | Template A | Template B | Template C |
|-------|--------------|------------|------------|
| Name | `aap-demo-01-validate` | `aap-demo-02-publish` | `aap-demo-03-finalize` |
| Inventory | Your demo inventory | same | same |
| Project | `aap-demo` project | same | same |
| Playbook | `playbooks/01_validate_environment.yml` | `playbooks/02_publish_workflow_stats.yml` | `playbooks/03_finalize.yml` |
| Execution environment | Your EE | same | same |

Enable **Privilege escalation** only if required.

### Workflow job template

**Templates** → **Add** → **Workflow Job Template** → name **`aap-demo-workflow`**.

Visualizer — chain on success:

**Start** → **`aap-demo-01-validate`** → **`aap-demo-02-publish`** → **`aap-demo-03-finalize`** → **End**

Launch the workflow. Confirm step 3 output contains **`demo_batch_id`** from **`set_stats`** in step 2.

### RBAC

Grant the demo **Team** or user permission to read the **Project**, use the **Inventory**, and execute the **Job** / **Workflow** templates. Avoid **Organization Admin** unless required.

---

## Extensions

- **Collections / EE:** [`collections/requirements.yml`](collections/requirements.yml), [`execution-environment/README.md`](execution-environment/README.md), **[documentation/ANSIBLE_COLLECTIONS.md](documentation/ANSIBLE_COLLECTIONS.md)**.
- **Remote inventory and credentials** for non-local targets.
- **Configuration as code:** e.g. **`ansible.controller`** collection — [Red Hat Ansible Automation Platform documentation](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/).
