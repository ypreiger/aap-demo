# UC-01 — OpenShift Virtualization + dual-control approval

## Story

Operators provision a BOM namespace and Fedora VMs for a tenant. A **manual approval gate** separates “platform prep” from “consumes IPs / CPU quotas” VM creation.

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
