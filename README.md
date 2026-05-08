# Ansible Automation Platform — `aap-demo`

## Repository layout

| Path | Contents |
|------|----------|
| **`playbooks/`** | Playbooks; **`inventory/`** hosts; **`collections/requirements.yml`** Galaxy allow list |
| **`workshop/`** | Multi-domain workflows, mock infra, E2E scripts — start at **[workshop/README.md](workshop/README.md)** and **[workshop/CLIENT_RUNBOOK.md](workshop/CLIENT_RUNBOOK.md)** |
| **`documentation/`** | **[documentation/README.md](documentation/README.md)** — index; **[documentation/INSTALL_OPENSHIFT.md](documentation/INSTALL_OPENSHIFT.md)** — **greenfield cluster** (operator → collections → workshop) |
| **`aap-yamls/`** | Automation Controller / Tower Kubernetes manifests — **[aap-yamls/README.md](aap-yamls/README.md)** |
| **`projects/`** | BOM and domain YAML (`proj1`, `proj2`) — **[documentation/DOMAIN_INPUT.md](documentation/DOMAIN_INPUT.md)** |
| **`email-plugin/`** | Approval email service — **[email-plugin/README.md](email-plugin/README.md)** |

**Git-driven workflows:** **[documentation/EDA_GIT_WEBHOOK.md](documentation/EDA_GIT_WEBHOOK.md)** and **`workshop/git-webhook-bridge/`**.

**Collections and EE:** **[documentation/COLLECTION_REFERENCE.md](documentation/COLLECTION_REFERENCE.md)**. Verify locally: **`./scripts/verify-collections-and-ee.sh`**.

**OpenShift Virtualization / surveys:** **[documentation/VIRT_WORKFLOW_SURVEY.md](documentation/VIRT_WORKFLOW_SURVEY.md)**.

**BOM workflows** (`bom-project-deploy`, surveys): use **`project_name`** → **`aap-demo/projects/{project_name}/bom`**. Attach credential **`openshift-bom-target`** (OpenShift/Kubernetes API bearer token) to **`bom-project-foundation`** and **`bom-project-vms`**. **Git ↔ cluster:** pushes under **`projects/`** can drive sync + gated workflows; cluster-only changes are not pushed back to Git — see **[documentation/PROJECTS_GIT_SYNC.md](documentation/PROJECTS_GIT_SYNC.md)**.

**Approval email:** **`email-plugin/`** + **[documentation/EMAIL_APPROVAL.md](documentation/EMAIL_APPROVAL.md)**.

**Namespace → approval email → NetworkPolicy:** workflow **`email-e2e-ns-netpol`** — **[documentation/USECASE_UC07_email_e2e_namespace_netpol.md](documentation/USECASE_UC07_email_e2e_namespace_netpol.md)**; apply **`oc apply -k aap-yamls/tower/`**, then **`scripts/register-webhook-email-e2e-ns-netpol.sh`**.

---

## New OpenShift cluster (full recreation)

Follow **[documentation/INSTALL_OPENSHIFT.md](documentation/INSTALL_OPENSHIFT.md)** for prerequisites, **AAP operator and platform instance**, **Automation Hub** community sync, **Controller** Galaxy credential and project sync, **`openshift-bom-target`** credential, **`oc apply -k aap-yamls/tower/`**, **mock infra**, **`email-plugin`** + webhooks, **`run-e2e-multi-domain-workflow.sh`**, optional **Git/EDA** and **RBAC**, then **[documentation/USECASE_INDEX.md](documentation/USECASE_INDEX.md)**.

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

- Sync **Community** using **[documentation/COLLECTION_HUB.md](documentation/COLLECTION_HUB.md)** and **`scripts/hub-sync-community-from-requirements.sh`**.
- Sync **Published** using an offline token — **§2** in the same file and **`scripts/hub-sync-rh-certified-from-secret.sh`**; if the gateway **Published** list stays empty after **`rh-certified`** sync, run **`scripts/hub-sync-published-mirror-rh-certified.sh`** (**§2.6** in that doc).

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

- **Collections / EE:** [`collections/requirements.yml`](collections/requirements.yml), [`execution-environment/README.md`](execution-environment/README.md), **[documentation/COLLECTION_REFERENCE.md](documentation/COLLECTION_REFERENCE.md)**.
- **Remote inventory and credentials** for non-local targets.
- **Configuration as code:** e.g. **`ansible.controller`** collection — [Red Hat Ansible Automation Platform documentation](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/).
