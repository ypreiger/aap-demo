# Install and recreate the workshop on a new OpenShift cluster

This runbook is the **ordered path** to stand up the same environment this repository expects: **Ansible Automation Platform (bundle)** on OpenShift, **Automation Hub** collections, **Automation Controller** project + credentials, **Tower resource operator** manifests, **mock infra**, **`email-plugin`**, and the **workshop** workflows. Deep dives stay in the linked files to avoid drift.

**Canonical repo:** [ypreiger/aap-demo](https://github.com/ypreiger/aap-demo) — clone it on a workstation with **`oc`**, **`kubectl`**, **`ansible-playbook`**, and network access to the cluster API and (later) gateway HTTPS.

---

## Prerequisites

| Requirement | Why |
|-------------|-----|
| **OpenShift** cluster with admin or sufficient rights to install operators, create namespace **`aap`**, apply **`AnsibleAutomationPlatform`**, Routes, BuildConfigs | Matches manifests under **`aap-yamls/`** |
| **`oc`** logged in (`oc whoami`) | All apply steps |
| **Storage class** for Hub file storage (default in CR may assume ODF CephFS) | Edit **`aap-yamls/01-ansibleautomationplatform.yaml`** if your cluster differs — see [aap-yamls/README.md](../aap-yamls/README.md) |
| **Git** fork or clone URL you will put in **`AnsibleProject`** (shipped example points at GitHub) | Controller sync; change CR if you use a private fork |
| **`jq`** and **`curl`** | Required by **`workshop/scripts/run-e2e-multi-domain-workflow.sh`** |
| **OpenShift Virtualization** (KubeVirt) installed and usable | Only if you run BOM / **`workshop-multi-domain`** VM steps — see [VIRT_WORKFLOW_SURVEY.md](VIRT_WORKFLOW_SURVEY.md) |
| **Outbound** from nodes/builders: registries for AAP images; from **`email-plugin`** pod: SMTP (e.g. Gmail) + Controller HTTPS | Builds and mail |

Red Hat install reference: [Installing AAP on OpenShift 2.6](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html/installing_on_openshift_container_platform/index).

---

## Phase 1 — Ansible Automation Platform operator and namespace

1. Create project **`aap`** (if not already present).
2. Install the **Ansible Automation Platform** operator from OperatorHub (subscription name typically **`ansible-automation-platform-operator`**) into **`aap`**, following the product guide for your OpenShift version.

Until the operator is **Succeeded**, do not expect **`AnsibleAutomationPlatform`** instances to reconcile.

---

## Phase 2 — Platform instance (gateway, Controller, Hub, EDA bundle)

From the **repository root**:

```bash
oc apply -k aap-yamls/
```

Wait until the instance and routes are healthy:

```bash
oc get ansibleautomationplatform -n aap
oc get routes,pods -n aap
```

- Retrieve the **admin** password: Secret name pattern **`{instance-name}-admin-password`** (bundled CR uses **`demo-aap-admin-password`** — confirm with `oc get secrets -n aap | grep admin-password`).
- Open the **gateway** Route URL; confirm tiles for Hub, Controller, etc.

Details and tunables (storage class, hostname, MCP/Lightspeed): **[`aap-yamls/README.md`](../aap-yamls/README.md)**.

---

## Phase 3 — API secret for OpenShift-side automation (`tower` operator)

Resource operator CRs need a Controller **OAuth token** and **HTTPS API host**:

1. Copy **`aap-yamls/secrets/aap-controller-api-secret.example.yaml`**.
2. Replace **`REPLACE_*`** with the Controller **Route** host (HTTPS) and a **personal access token** from the gateway / Controller user settings.
3. Apply as **`Secret/aap-controller-api`** in namespace **`aap`**.

```bash
oc apply -f aap-yamls/secrets/<your-file>.yaml   # metadata.name: aap-controller-api
```

This Secret is reused by **`email-plugin`** (deploy script patches `CONTROLLER_*` from it).

---

## Phase 4 — Automation Hub: community collections

If Hub **`/content/collections`** is empty, mirror **`collections/requirements.yml`** into the **community** repository:

```bash
export HUB_GATEWAY_URL="https://<your-gateway-host>"
./scripts/hub-sync-community-from-requirements.sh
```

In the UI, filter by **Community** if **Published** is still empty. Certified / **rh-certified** flow: [COLLECTION_HUB.md](COLLECTION_HUB.md) §2 and **`scripts/hub-sync-rh-certified-from-secret.sh`**.

---

## Phase 5 — Automation Controller: Galaxy credential, collection download, Git sync

Controller does **not** install collections from **`requirements.yml`** until **collection download** is enabled and a **Galaxy/Hub** credential exists on the **Organization** used by the project.

1. Follow [COLLECTION_CONTROLLER.md](COLLECTION_CONTROLLER.md) (UI checklist).
2. Or run **`./scripts/controller-wire-galaxy-for-default-org.sh`** against your Controller API (same host/token as Phase 3).
3. Optional: apply **`aap-yamls/tower/ansiblecredential-galaxy-ansible-com.yaml`** if you manage that credential in Git (not always in **`kustomization.yaml`** — see **`aap-yamls/tower/`**).
4. In Controller: **Projects** → open **`AAP Demo (GitHub)`** (or your renamed project) → **Sync** so playbooks and **`collections/requirements.yml`** exist on the execution path.

---

## Phase 6 — Controller credential for OpenShift/Kubernetes API (BOM playbooks)

**Not** applied from Git: create credential **`openshift-bom-target`** in Controller (**OpenShift or Kubernetes API Bearer Token**) with:

- API URL of **this** cluster (or target cluster)
- Service account token (and CA / SSL verification as appropriate)

Attach it to job templates **`bom-project-foundation`** and **`bom-project-vms`** (already expected by the shipped CRs). Without it, **`kubernetes.core`** fails at runtime.

---

## Phase 7 — Tower CRs (job templates, workflow templates)

```bash
oc apply -k aap-yamls/tower/
```

Wait until **`WorkflowTemplate`** / **`JobTemplate`** objects report success in **`oc get workflowtemplate,jobtemplate -n aap`**.

If the **`bom-project-deploy`** visualizer is empty or CRs error: **sync the Git project** first so **`playbooks/project_foundation.yml`** and **`playbooks/project_vms.yml`** exist — see troubleshooting in **[`aap-yamls/README.md`](../aap-yamls/README.md)**.

**Optional:** submit one workflow from OpenShift using overlays (re-run cautiously in GitOps loops):

```bash
oc apply -k aap-yamls/tower-full-run-proj1/
```

---

## Phase 8 — Workshop mock HTTP APIs (F5 / VMware / Blue Coat JSON)

```bash
oc apply -k workshop/openshift/mock-infra
```

Resolve the Route host for surveys and E2E:

```bash
bash workshop/scripts/resolve-mock-route.sh
```

Use the printed **`https://…`** origin (no trailing slash) as **`workshop_mock_base_url`** when launching **`workshop-multi-domain`**.

---

## Phase 9 — `email-plugin` (approval mail)

1. Deploy (build + Route + Deployment):

   ```bash
   SMTP_PASSWORD='<gmail-app-password>' DISABLE_SMTP=false ./email-plugin/scripts/deploy-email-plugin.sh
   ```

2. Register the Controller **webhook notification** on **`bom-project-deploy`** (and optionally other workflows): [EMAIL_APPROVAL.md](EMAIL_APPROVAL.md) §4, or the copy-paste block in **[`email-plugin/README.md`](../email-plugin/README.md)**.

3. For **`email-e2e-ns-netpol`**, run **`scripts/register-webhook-email-e2e-ns-netpol.sh`** after reading [USECASE_UC07_email_e2e_namespace_netpol.md](USECASE_UC07_email_e2e_namespace_netpol.md).

---

## Phase 10 — Verify the multi-domain workshop

With Hub collections visible, Controller project synced, **`openshift-bom-target`** present, mock Route up, and (if you use mail) **`email-plugin`** + webhook registered:

```bash
bash workshop/scripts/run-e2e-multi-domain-workflow.sh
```

The script expects **`Secret/aap-controller-api`** in **`aap`** (override with **`AAP_NAMESPACE`**) and a Controller project named **`AAP Demo (GitHub)`** (as created by the shipped **`AnsibleProject`** CR). If you renamed the project, launch **`workshop-multi-domain`** from the UI instead.

Fix failures using **[`workshop/PLAN.md`](../workshop/PLAN.md)** (execution order) and **[`workshop/CLIENT_RUNBOOK.md`](../workshop/CLIENT_RUNBOOK.md)** (UI equivalents).

**Legacy CR cleanup** (optional): **`./aap-yamls/scripts/cleanup-legacy-bom-resources.sh`** then re-apply **`aap-yamls/tower/`**.

---

## Phase 11 — Optional: Git → EDA → gated workflow

Deploy **`workshop/git-webhook-bridge`**, apply **`workflowtemplate-workshop-projects-git-driven`**, register GitHub webhook — [EDA_GIT_WEBHOOK.md](EDA_GIT_WEBHOOK.md).

For how **`projects/`** in Git maps to **one** Controller SCM project, approval semantics, and **cluster → Git** (not shipped), read [PROJECTS_GIT_SYNC.md](PROJECTS_GIT_SYNC.md).

---

## Phase 12 — Optional: workshop RBAC bootstrap

```bash
./scripts/workshop-rbac-bootstrap.sh
```

Uses Controller API; align with [WORKSHOP_RBAC.md](../workshop/WORKSHOP_RBAC.md).

---

## Use cases (operator checklists)

After the stack is up, walk scenarios **UC-01–UC-07**: [USECASE_INDEX.md](USECASE_INDEX.md).

---

## Quick reference (copy order)

| Step | Command / action |
|------|------------------|
| Platform | `oc apply -k aap-yamls/` |
| Secret | `oc apply -f …/aap-controller-api-secret.yaml` |
| Hub sync | `./scripts/hub-sync-community-from-requirements.sh` |
| Controller wiring | [COLLECTION_CONTROLLER.md](COLLECTION_CONTROLLER.md) or `./scripts/controller-wire-galaxy-for-default-org.sh` |
| Credential | UI: **`openshift-bom-target`** |
| Tower CRs | `oc apply -k aap-yamls/tower/` |
| Mock | `oc apply -k workshop/openshift/mock-infra` |
| Mail | `./email-plugin/scripts/deploy-email-plugin.sh` + [EMAIL_APPROVAL.md](EMAIL_APPROVAL.md) §4 |
| E2E | `bash workshop/scripts/run-e2e-multi-domain-workflow.sh` |

---

## Related documentation

| Topic | File |
|-------|------|
| Manifest details | [../aap-yamls/README.md](../aap-yamls/README.md) |
| Collections reference | [COLLECTION_REFERENCE.md](COLLECTION_REFERENCE.md) |
| Domain YAML | [DOMAIN_INPUT.md](DOMAIN_INPUT.md) |
| Git ↔ `projects/` layout | [PROJECTS_GIT_SYNC.md](PROJECTS_GIT_SYNC.md) |
| Virt survey fields | [VIRT_WORKFLOW_SURVEY.md](VIRT_WORKFLOW_SURVEY.md) |
| Doc index | [README.md](README.md) |
