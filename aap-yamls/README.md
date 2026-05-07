# OpenShift / AAP 2.6 manifests

Kubernetes/OpenShift objects for a **bundle** `AnsibleAutomationPlatform` deployment (gateway **Route**, Controller, Hub, **EDA**, **MCP**, optional **Lightspeed** off by default) plus **Tech Preview** `tower.ansible.com` CRs for the [aap-demo](https://github.com/ypreiger/aap-demo) job / workflow chain.

References: [Installing AAP on OpenShift 2.6](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html/installing_on_openshift_container_platform/index).

## Apply order

1. **Subscription / operator** (already done in your workshop): `ansible-automation-platform-operator` in namespace `aap`.

2. **Platform instance** (run from the **repository root**, next to the `aap-yamls/` directory)

   ```bash
   oc apply -k aap-yamls/
   ```

   Wait until routes and pods are healthy:

   ```bash
   oc get ansibleautomationplatform -n aap
   oc get routes,pods -n aap
   ```

   Admin password Secret name follows `{metadata.name}-admin-password` (here `demo-aap-admin-password`).

3. **Controller API Secret** used by Resource Operator CRs (`tower.ansible.com`):

   - Copy `secrets/aap-controller-api-secret.example.yaml`, replace `REPLACE_*` values, apply as `Secret/aap-controller-api`.

   Use the **HTTPS Route** for the automation controller/API (from `oc get route -n aap`) unless you intentionally trust the cluster service CA from the operator pods.

4. **Projects / templates / workflow** (after controller project sync works and `Default` organization + **Demo Inventory** exist — enabled via `controller.create_preload_data: true`)

   ```bash
   oc apply -k aap-yamls/tower/
   ```

   **Definitions only** (`WorkflowTemplate` / `JobTemplate` sync to Controller). To also **submit a workflow job** from OpenShift (Tech Preview **`AnsibleWorkflow`**), use an overlay that layers a run on top of `tower/`:

   ```bash
   oc apply -k aap-yamls/tower-full-run-proj1/
   # or: oc apply -k aap-yamls/tower-full-run-proj2/
   ```

   That expands to everything in `tower/` plus one **`AnsibleWorkflow`** with `extra_vars.project_name` set. Treat **`AnsibleWorkflow`** like any job trigger: repeating `oc apply` after deleting the CR can launch again; CI/GitOps loops may resubmit depending on controller/operator behaviour—prefer **`tower/`** alone for reconcile-only manifests and launch manually from Controller when you want a human survey.

## Configuration you may need to change

| File | knob |
|------|------|
| `01-ansibleautomationplatform.yaml` | `hub.file_*` storage class / size (`ocs-external-storagecluster-cephfs` assumes ODF CephFS; change if your cluster differs). |
| same | Uncomment `hostname` to pin the gateway Route host under your `*.apps...` domain. |
| same | Lightspeed is `disabled: true`; enable only with valid IBM/auth secrets per product docs. |

## MCP and Lightspeed

- **MCP** is enabled read-only (`allow_write_operations: false`). See chapter *Deploying an Ansible MCP server* in the install guide.
- **Lightspeed** requires IBM watsonx Code Assistant configuration secrets; enable in the CR after you create those secrets ([install guide — Lightspeed](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html/installing_on_openshift_container_platform/index)).

EDA and Controller URLs are wired by the platform operator when deployed from the bundled CR; no standalone `EDA` CR is needed for this layout.

## BOM / namespaces (`projects/`)

BOM layouts:

- **`projects/<project_name>/bom/`** — `namespace.yaml`, `serviceaccount.yaml` (**`<project_name>-sa`**), **`networkpolicy.yaml`**, **`vm-fedora-01.yaml`** / **`vm-fedora-02.yaml`**.
- Repo ships **`projects/proj1`** and **`projects/proj2`**; names in YAML files must match the folder (**`project_name`** extra var equals that folder).

Automation:

- **`playbooks/project_foundation.yml`** — create namespace → **validate Active** → SA → **validate exists** → NetworkPolicy → **validate exists**.
- **`playbooks/project_vms.yml`** — prerequisite checks foundation objects, then applies & validates Fedora **VirtualMachine** CRs (**CNV/KubeVirt** required).

Tower (YAML in **`tower/`**):

| Name | Purpose |
|------|---------|
| **`bom-project-foundation`** | Job template → foundation playbook. |
| **`bom-project-vms`** | Job template → VM playbook **only after** foundation succeeds. |
| **`bom-project-deploy`** | Generic workflow (**not** proj1/proj2-specific). **Survey** presents a launch dialog for **`project_name`** (Git path `aap-demo/projects/{project_name}/bom`). Then: foundation → **`workflow_approval`** `bom-approve-before-vms` → VMs. |
| **`AnsibleWorkflow` `awf-bom-project-deploy-proj1`** (overlay) | Submits **one Workflow Job** to Controller for **`bom-project-deploy`** with **`project_name: proj1`** (survey values via `extra_vars`). Declared under **`tower-full-run-proj1/`**; **`proj2`** variant in **`tower-full-run-proj2/`**. |

`WorkflowTemplate` (CR kind) maps to Automation Controller **Workflow Job Template**; **`AnsibleWorkflow`** maps to a **Workflow Job execution** initiated from OpenShift once the CR is reconciled.

**Remove legacy Controller objects** (e.g. UI name `proj1-apply-bom-workflow` from deleted CRs):

```bash
./aap-yamls/scripts/cleanup-legacy-bom-resources.sh
oc apply -k aap-yamls/tower/
```

Re-sync Git project in Controller after pushing, then **`oc apply -k aap-yamls/tower/`** if you reconcile from Git.

Approval email (SMTP + workflow **Approval** notifications): see repository **[`documentation/CONFIGURE_AAP_APPROVAL_EMAIL.md`](../documentation/CONFIGURE_AAP_APPROVAL_EMAIL.md)**.

```bash
oc apply -k aap-yamls/tower/
```

## Repository

This folder is tracked in **[ypreiger/aap-demo](https://github.com/ypreiger/aap-demo)** at path **`aap-yamls/`**. From clone root:

```bash
git add aap-yamls
git commit -m "Update OpenShift AAP bundle manifests"
git push origin main
```
