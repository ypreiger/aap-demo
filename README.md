# Red Hat Ansible Automation Platform — minimal workflow demo

**Layout:** playbook content under **`playbooks/`** (plus **`inventory/`**, **`collections/requirements.yml`**). **Multi-domain presenter workshop (Virt + netpol + mock F5/VMware/Blue Coat + EDA/RBAC notes):** see **[workshop/README.md](workshop/README.md)** and **[workshop/CLIENT_RUNBOOK.md](workshop/CLIENT_RUNBOOK.md)** (*which Controller workflow to run and what you should see*); run **`workshop/scripts/run-e2e-multi-domain-workflow.sh`** after applying **`workshop/openshift/mock-infra`**. **Git `projects/` changes:** **[documentation/GIT_WEBHOOK_EDA.md](documentation/GIT_WEBHOOK_EDA.md)** + **`workshop/git-webhook-bridge`** (EDA envelope + SCM sync + gated workflow **workshop-projects-git-driven**); domain inputs use YAML under **`projects/*/domain/`** (**[DOMAIN_INPUT_YAML.md](documentation/DOMAIN_INPUT_YAML.md)**). **Infrastructure collections & EE:** see **[documentation/ANSIBLE_COLLECTIONS.md](documentation/ANSIBLE_COLLECTIONS.md)** (OpenShift Virtualization/KubeVirt, VMware, F5; Blue Coat / ProxySG has no mainstream Galaxy module—patterns documented). **Verify installs + EE context + playbook syntax:** `./scripts/verify-collections-and-ee.sh` (also runs in **GitHub Actions**). OpenShift BOM artefacts live under **`projects/<project_name>/bom`** (currently **`proj1`** and **`proj2`**). **`playbooks/project_foundation.yml`** creates namespace / SA / netpol each with validation; **`playbooks/project_vms.yml`** templates Fedora **VirtualMachine** CRs (KubeVirt) using **OpenShift Virtualization cluster instance types / preferences** or **manual** CPU+RAM, plus **survey‑driven** root / extra disks (**[documentation/VIRTUALIZATION_WORKFLOW_SURVEY.md](documentation/VIRTUALIZATION_WORKFLOW_SURVEY.md)**). **BOM playbooks need a cluster API:** in Automation Controller attach **OpenShift or Kubernetes API Bearer Token** credential **`openshift-bom-target`** to **`bom-project-foundation`** / **`bom-project-vms`** (no `~/.kube/config` in the execution environment). The controller workflow **`bom-project-deploy`** is **generic** (not named after a project). Launch opens a **survey** for **`project_name`**, which selects Git path **`aap-demo/projects/{project_name}/bom`**, then runs foundation, **approval**, then VMs. Operator examples in **`aap-yamls/`** ([README](aap-yamls/README.md)). **Approval email (click Approve/Deny in Gmail):** use this repo’s **`email-plugin/`** ([README](email-plugin/README.md)) plus [documentation/CONFIGURE_AAP_APPROVAL_EMAIL.md](documentation/CONFIGURE_AAP_APPROVAL_EMAIL.md); optional native Controller SMTP stays in `playbooks/controller_configure_bom_approval_email.yml`.

---

This repository is a short, presenter-friendly automation **storyline** made for **Ansible Automation Platform (AAP)**:

1. **Validate** execution context (`playbooks/01_validate_environment.yml`).
2. **Publish** a workflow artifact using `set_stats` (`playbooks/02_publish_workflow_stats.yml`).
3. **Finalize** and show the propagated `demo_batch_id` (`playbooks/03_finalize.yml`).

Run locally (optional sanity check):

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ansible-playbook playbooks/01_validate_environment.yml
ansible-playbook playbooks/02_publish_workflow_stats.yml
ansible-playbook playbooks/03_finalize.yml
```

Inside a **Workflow Job Template**, step 3 receives `demo_batch_id` from step 2. Run alone, step 3 prints `n/a` for that variable by design.

---

## AAP components to configure (checklist)

Use **Automation Controller** (AAP’s control plane UI or API). Names below are suggestions; align with your org’s naming conventions.

### Automation Hub (collections browser)

Presenters validating **`/content/collections`** should ensure the **`community`** repository is synced (**`requirements_file`** from this repo drives the allow list). Scripted path: **`documentation/HUB_COLLECTIONS.md`** and **`scripts/hub-sync-community-from-requirements.sh`**.

### 1. Organization (optional but typical)

Create or reuse an **Organization** (for example `Demo`).

### 2. Execution environment (EE)

- **Automation Execution Environments** → **Add**.
- Use a supported image that includes **Ansible** and **ansible-runner** (for example a platform-provided **minimal** EE, or your own EE built with `ansible-builder`).
- Attach the EE where policies allow (`Global` org or scoped to your org).

Jobs need an EE whose Python/Ansible version matches content you intend to scale to later.

### 3. Credentials

| Credential type | Purpose |
|-----------------|--------|
| **Source Control** | Clone `https://github.com/ypreiger/aap-demo` |
| *(optional)* **Machine / SSH / Vault** | Not required for `localhost`/local-connection demo |

For GitHub HTTPS, prefer a **Personal Access Token** as the password and your Git username (or a dedicated automation user).

### 4. Project

- **Projects** → **Add**.
- **Source Control URL**: `https://github.com/ypreiger/aap-demo`
- **Credential**: the Source Control credential from step 3.
- Save and wait for initial **sync** to succeed (**green last job**).

### 5. Inventory

- **Inventories** → **Add** → **Demo inventory**.
- **Sources** tab is optional here; simplest path is **Hosts** → **Add** → `localhost`.
- Variables for that host:

```yaml
ansible_connection: local
```

(or import `inventory/hosts.yml` semantics manually as above.)

### 6. Job Templates (three)

Create **three** templates; each type **Ansible Playbook**:

| Field | Template A | Template B | Template C |
|-------|------------|------------|------------|
| Name | `aap-demo-01-validate` | `aap-demo-02-publish` | `aap-demo-03-finalize` |
| Inventory | Demo inventory | same | same |
| Project | Your `aap-demo` project | same | same |
| Playbook | `playbooks/01_validate_environment.yml` | `playbooks/02_publish_workflow_stats.yml` | `playbooks/03_finalize.yml` |
| Execution environment | Your EE | same | same |

Enable **Privilege escalation** only if your environment requires it (not needed for these playbooks).

### 7. Workflow Job Template

- **Templates** → **Add** → **Workflow Job Template**.
- Name: `aap-demo-workflow`.
- Optionally set **Survey**, **Notifications**, and **Scheduling** afterward.

**Visualizer**: add nodes in order:

- Start → **`aap-demo-01-validate`** → **`aap-demo-02-publish`** → **`aap-demo-03-finalize`** → End

Connect with **On Success** edges so failure stops the chain (good for live demos).

Launch the **workflow** and show:

- Per-node **job output** in the workflow run view.
- Step 3 output containing `demo_batch_id` populated from `set_stats` in step 2.

### 8. RBAC (for shared platforms)

Grant your demo **Team** (or user) minimally:

- Read **Project**/sync, use **Inventory**, execute **Job Template** / **Workflow Job Template** on the demo objects.

Avoid giving **Organization Admin** unless required.

---

## After this demo

Extend the storyline with:

- **Galaxy collections** for OpenShift virtualization, VMware, F5 (and ProxySG posture): **`collections/requirements.yml`**, **`execution-environment/`**, **[documentation/ANSIBLE_COLLECTIONS.md](documentation/ANSIBLE_COLLECTIONS.md)**.
- Remote **inventory** and **machine credentials**.
- Configuration as code (for example **`ansible.controller`**) to reproducibly define Projects, JT, workflows, and RBAC ([Ansible Automation Platform documentation](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/)).
