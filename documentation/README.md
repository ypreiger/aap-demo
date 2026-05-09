# Documentation (`aap-demo`)

All guides live under **`documentation/`**. The repository **[`README.md`](../README.md)** summarizes layout and quick checks; use this file as the **index** for setup and operations.

**New OpenShift cluster (full stack):** start with **[`INSTALL_OPENSHIFT.md`](INSTALL_OPENSHIFT.md)** — prerequisites, AAP instance, Hub and Controller collections, Tower CRs, mock infra, **`email-plugin`**, verification, and pointers to use cases.

---

## `COLLECTION_*` — Automation Hub and Controller

| File | Contents |
|------|----------|
| [COLLECTION_HUB.md](COLLECTION_HUB.md) | Hub UI filters; **community** sync; **rh-certified** / **published** mirror; offline token; scripts |
| [COLLECTION_CONTROLLER.md](COLLECTION_CONTROLLER.md) | Project sync, Galaxy/Hub credential on organization, collection download, EE |
| [COLLECTION_REFERENCE.md](COLLECTION_REFERENCE.md) | Which collections this repo uses (KubeVirt, VMware, F5, ProxySG patterns) |

Scripts: `scripts/hub-sync-community-from-requirements.sh`, `scripts/hub-sync-rh-certified-from-secret.sh`, `scripts/hub-sync-published-mirror-rh-certified.sh`.

---

## `EMAIL_*` — Approval mail and `email-plugin`

| File | Contents |
|------|----------|
| [EMAIL_APPROVAL.md](EMAIL_APPROVAL.md) | Flow diagrams, deploy, webhook registration, extra workflows, optional SMTP-only path, troubleshooting |

Pod reference: [`email-plugin/README.md`](../email-plugin/README.md).

---

## `EDA_*` — Git webhook and Event-Driven Ansible

| File | Contents |
|------|----------|
| [EDA_GIT_WEBHOOK.md](EDA_GIT_WEBHOOK.md) | **`workshop/git-webhook-bridge`**, EDA envelope, Controller SCM sync, gated workflow |

---

## `USECASE_*` — Operator procedures (UC-01–UC-07)

Index: [USECASE_INDEX.md](USECASE_INDEX.md)

| UC | File |
|----|------|
| UC-01 | [USECASE_UC01_openshift_virt_and_approval.md](USECASE_UC01_openshift_virt_and_approval.md) |
| UC-02 | [USECASE_UC02_network_policy_audit.md](USECASE_UC02_network_policy_audit.md) |
| UC-03 | [USECASE_UC03_mock_f5_vmware_bluecoat.md](USECASE_UC03_mock_f5_vmware_bluecoat.md) |
| UC-04 | [USECASE_UC04_eda_awareness.md](USECASE_UC04_eda_awareness.md) |
| UC-05 | [USECASE_UC05_inspect_hub_collections_bluecoat.md](USECASE_UC05_inspect_hub_collections_bluecoat.md) |
| UC-06 | [USECASE_UC06_approve_by_email_buttons.md](USECASE_UC06_approve_by_email_buttons.md) |
| UC-07 | [USECASE_UC07_email_e2e_namespace_netpol.md](USECASE_UC07_email_e2e_namespace_netpol.md) |

Condensed operator path: [../workshop/CLIENT_RUNBOOK.md](../workshop/CLIENT_RUNBOOK.md).

---

## `DOMAIN_*` / `VIRT_*` / Git layout

| File | Contents |
|------|----------|
| [DOMAIN_INPUT.md](DOMAIN_INPUT.md) | Domain YAML under **`projects/*/domain/`** |
| [VIRT_WORKFLOW_SURVEY.md](VIRT_WORKFLOW_SURVEY.md) | OpenShift Virtualization / workflow survey fields |
| [PROJECTS_GIT_SYNC.md](PROJECTS_GIT_SYNC.md) | Controller **Project** (SCM) vs **`projects/<slug>/`**, Git→cluster vs cluster→Git |

## Lightspeed

| File | Contents |
|------|----------|
| [LIGHTSPEED_ASSISTANT.md](LIGHTSPEED_ASSISTANT.md) | Assistant visible but not answering — LLM secret, logs, egress |

---

## Workshop (non-doc)

| Path | Role |
|------|------|
| [../workshop/PLAN.md](../workshop/PLAN.md) | Rollout order and checklist |
| [../workshop/WORKSHOP_RBAC.md](../workshop/WORKSHOP_RBAC.md) | Controller RBAC notes |
| [../workshop/git-webhook-bridge/](../workshop/git-webhook-bridge/) | Bridge source |
