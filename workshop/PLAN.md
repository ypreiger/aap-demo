# Plan — Multi-domain AAP on OpenShift workshop

Canonical repository: [ypreiger/aap-demo](https://github.com/ypreiger/aap-demo).

This document is the **execution contract** for presenters and for **AI agents** coordinating the build. It merges content, cluster wiring, and QA.

## Objectives

1. Teach **Automation Controller** on OpenShift chaining **OpenShift Virtualization** (BOM + NetworkPolicy) with **mock integrations** for VMware, F5, and Blue Coat—mirroring how enterprises split domains while sharing a platform.
2. Use **human approval gates** + **`email-plugin`** for mail-driven Approve/Deny.
3. Acknowledge **EDA** (Event-Driven Ansible) as the event fabric (health check + doc path for rulebooks)—UI is often disabled on sandbox bundles; automation still hits the public Route.
4. Apply **RBAC** so each domain team is a **Team** in Controller with least privilege (bootstrap script + manual fine-tuning).
5. Keep **everything in Git**: manifests, playbooks, agent briefs, verification scripts.

## Architecture (runtime)

| Layer | Artefact | Notes |
|-------|----------|--------|
| Mock APIs | `workshop/openshift/mock-infra/` | Nginx + ConfigMap JSON; Route `workshop-mock-infra` |
| Virt & policy | `playbooks/project_foundation.yml`, `project_vms.yml`, `workshop_networkpolicy_audit.yml` | `kubernetes.core` (collections from project sync / EE) |
| Mock domain playbooks | `playbooks/workshop_mock_*.yml` | `ansible.builtin.uri` only |
| Workflow | `workflowtemplate-workshop-multi-domain.yaml` | `workshop-multi-domain` WT |
| Secrets / API | `Secret/aap-controller-api` | Bearer token automation |
| Mail | `email-plugin/` | Webhook on approval |

## Deliverables checklist

- [x] **Client-facing AAP UI steps** (**[`workshop/CLIENT_RUNBOOK.md`](CLIENT_RUNBOOK.md)**) — workflows to launch, collections, importing collections, Blue Coat, email approvals  
- [x] Mock infra Deployment + Route in `aap` namespace  
- [x] Workshop job templates + workflow (Tower resource operator CRs)  
- [x] E2E script with **auto-approve** for CI-like verification  
- [x] Cleanup helper for stale legacy CRs / optional Controller objects  
- [x] Agent instruction packs (`workshop/agents/`)  
- [x] Per-domain narratives (`workshop/use-cases/`)  
- [x] Email subject prefix + richer template context  

## Execution order (operators / presenters)

1. **Automation Hub**: if **`/content/collections`** stays empty after install, mirror **`collections/requirements.yml`** into the **`community`** repo (**`documentation/HUB_COLLECTIONS.md`** + **`scripts/hub-sync-community-from-requirements.sh`**). In the gateway UI choose **Community** if **Published** is still blank (until **rh-certified** sync + token).  
2. `collections` + EE: enable Galaxy sync (see **`documentation/CONTROLLER_COLLECTIONS_VISIBILITY.md`**).  
3. `oc apply -k workshop/openshift/mock-infra`  
4. `oc apply -k aap-yamls/tower/` → wait until **workshop-multi-domain** WT exists  
5. Git project **Sync** (or run `workshop/scripts/run-e2e-multi-domain-workflow.sh` which triggers update)  
6. Register webhook: `ansible-playbook email-plugin/playbooks/register_controller_webhook_notification.yml …`  
7. Optional SMTP: `./email-plugin/scripts/deploy-email-plugin.sh`  
8. `bash workshop/scripts/run-e2e-multi-domain-workflow.sh`  

## Git-triggered executions

1. Ensure Tower exposes **`bom-approve-before-vms`** (**shared** with BOM workflow CRs — no extra bootstrap).
2. Apply **`workflowtemplate-workshop-projects-git-driven`** (**`jt-workshop-git-push-dispatcher`**).
3. Deploy **`workshop/git-webhook-bridge`**; set **`EDA_WEBHOOK_URL`** / **`GITHUB_WEBHOOK_SECRET`** when ready.
4. Register repo webhook **`POST …/v1/github`** targeting the bridge Route.

Incremental execution uses marker sets produced by **`app/classify.py`** (`openshift_virt` vs **`openshift_ns_bootstrap`** vs **`openshift_netpol_audit`**, domain YAML keys). Details: **`documentation/GIT_WEBHOOK_EDA.md`**.

## Risks / mitigations

| Risk | Mitigation |
|------|-------------|
| CNV quotas / flavours missing | Workflow survey knobs + doc `VIRTUALIZATION_WORKFLOW_SURVEY.md`; pick `manual` sizing if instances types unavailable |
| nginx image pull | Cluster pull-through; substitute mirrored `nginx-unprivileged` if deny-all |
| EDA JWT / UI off | Smoke `curl` only; presenters show rulebook YAML in-repo |
| RBAC granularity | Supplement script with Org Admin UI mapping |
