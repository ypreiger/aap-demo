# UC-01 — OpenShift Virtualization + dual-control approval

## Goal

Provision BOM namespace and Fedora VMs. A **manual approval** separates foundation jobs from VM creation.

## Prerequisites

- **`../PLAN.md`** execution order (mock infra, tower CRs applied, project sync).
- **Hub / collections:** **[`UC-05-inspect-hub-collections-bluecoat.md`](UC-05-inspect-hub-collections-bluecoat.md)** or **`../../documentation/HUB_COLLECTIONS.md`** + **`../../documentation/CONTROLLER_COLLECTIONS_VISIBILITY.md`**.
- **Mock route** for survey URL: `oc apply -k ../openshift/mock-infra` → `bash ../scripts/resolve-mock-route.sh`

---

## Instructions (step-by-step in AAP)

1. **Presenter** (terminal, once per cluster): ensure mock JSON is exposed:
   ```bash
   oc apply -k workshop/openshift/mock-infra   # from repo root
   bash workshop/scripts/resolve-mock-route.sh
   ```
   Copy the printed **`https://...`** line **with no trailing slash** — this is **`workshop_mock_base_url`**.
2. Open **Automation Controller** from the platform gateway.
3. **Templates** → **Workflow Templates**.
4. Locate **`workshop-multi-domain`** → **Launch**.
5. In the survey:
   - **Project name (BOM path):** e.g. **`proj1`** (must match `projects/<name>/bom` in Git).
   - **Mock integrations base URL:** paste the **`https://<workshop-mock-infra-host>`** from step **1**.
6. Submit. Open **Jobs** and select the new **workflow job**.
7. Wait until job **`bom-project-foundation`** completes (green) and the flow pauses at **`bom-approve-before-vms`**.
8. **Approval**:
   - **UI:** open the approval node → **Approve** (or **Deny** to stop before VMs).
   - **Email / buttons:** complete **[`UC-06-approve-by-email-buttons.md`](UC-06-approve-by-email-buttons.md)** **Path B** first, then use mail for the same gate when you re-run this workflow.
9. After **Approve**, **`workshop-bom-project-vms`** runs, then downstream jobs (netpol audit, mocks) follow automatically—see UC-02 and UC-03 for what each stage asserts.

### What you should see

| Stage | Expected signal |
|-------|------------------|
| **`bom-project-foundation`** | Logs show namespace/BOM resources from `projects/{project_name}/bom/`. |
| **`bom-approve-before-vms`** | Workflow **Pending** until someone approves (**UI** or **`UC-06` email**). |
| **`workshop-bom-project-vms`** | **VirtualMachine** CRs created (cluster needs OpenShift Virtualization + quota). |

---

## Controller objects

- Workflow **`workshop-multi-domain`** (survey: **`project_name`**, **`workshop_mock_base_url`**)
- Job templates **`bom-project-foundation`**, **`workshop-bom-project-vms`**
- Workflow approval **`bom-approve-before-vms`**
- Optional **`email-plugin`** webhook — **`UC-06`**

## Success criteria

- Namespace `projects/{project_name}/bom` artefacts applied per BOM playbooks.
- **VirtualMachine** objects exist after approval **or** workflow correctly stops on **Deny** without VMs.
- Approval email (if configured) matches **`UC-06`** success criteria.

## Rollback

`oc delete vm --all -n <project>` then `oc delete namespace <project>` (destructive; warn students).

## See also

- **[`../CLIENT_RUNBOOK.md`](../CLIENT_RUNBOOK.md)** §6 — full node table.
- **Simpler BOM-only flow (no mocks):** **`bom-project-deploy`** — good for VM survey variety; pair with **`UC-06` Path A** for email.
