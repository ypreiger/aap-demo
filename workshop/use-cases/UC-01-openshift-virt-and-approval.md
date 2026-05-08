# UC-01 — OpenShift Virtualization + dual-control approval

## Story

Operators provision a BOM namespace and Fedora VMs for a tenant. A **manual approval gate** separates “platform prep” from “consumes IPs / CPU quotas” VM creation.

## Prerequisites

Follow **`../PLAN.md`**. Automation Hub **`/content/collections`**: **`community`** sync + UI filter (**[`../../documentation/HUB_COLLECTIONS.md`](../../documentation/HUB_COLLECTIONS.md)**). Controller **`collections/requirements.yml`**: **`../../documentation/CONTROLLER_COLLECTIONS_VISIBILITY.md`**.

## Run this in AAP (step-by-step)

See **`workshop-multi-domain`** in **[`../CLIENT_RUNBOOK.md` §6](../CLIENT_RUNBOOK.md#6-workflow-workshop-multi-domain-step-by-step)** (survey **`project_name`**, **`workshop_mock_base_url`**, then approval **`bom-approve-before-vms`**).

For **clickable email Approve/Deny**, the default webhook is tied to **`bom-project-deploy`** unless you register separately for **`workshop-multi-domain`** — **[`../CLIENT_RUNBOOK.md` §5](../CLIENT_RUNBOOK.md#5-email-approval-approve-and-deny-buttons-in-email)**.

## Controller objects

- Workflow **`workshop-multi-domain`** (survey: **`project_name`**, **`workshop_mock_base_url`**)
- Job templates **`bom-project-foundation`**, **`workshop-bom-project-vms`**
- Workflow approval **`bom-approve-before-vms`**
- Webhook notification targeting **`email-plugin`**

## Success criteria

- Namespace `projects/{project_name}/bom` artefacts applied identical to BOM checks.
- **VirtualMachine** objects created with survey parameters.
- Approver email shows workflow template + approval description (email-plugin v2 template).

## Rollback

`oc delete vm --all -n <project>` then `oc delete namespace <project>` (destructive; warn students).
