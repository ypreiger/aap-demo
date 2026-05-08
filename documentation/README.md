# Documentation index (`aap-demo`)

Use this index to open the right guide. All paths are relative to the repository root.

## Automation Hub

| Document | Purpose |
|----------|---------|
| [HUB_COLLECTIONS.md](HUB_COLLECTIONS.md) | Empty Collections UI; **Community** sync; **Published / certified** sync; **offline token** and OpenShift **Secret** |
| [CONTROLLER_COLLECTIONS_VISIBILITY.md](CONTROLLER_COLLECTIONS_VISIBILITY.md) | Controller project sync, Galaxy/Hub credentials, EE |

## Automation Controller and workflows

| Document | Purpose |
|----------|---------|
| [CONFIGURE_AAP_APPROVAL_EMAIL.md](CONFIGURE_AAP_APPROVAL_EMAIL.md) | Deploy **`email-plugin`**, register approval webhook, Controller base URL |
| [ANSIBLE_COLLECTIONS.md](ANSIBLE_COLLECTIONS.md) | Collection choices (KubeVirt, VMware, F5, ProxySG patterns) |
| [CONTROLLER_COLLECTIONS_VISIBILITY.md](CONTROLLER_COLLECTIONS_VISIBILITY.md) | How job templates resolve collections |
| [VIRTUALIZATION_WORKFLOW_SURVEY.md](VIRTUALIZATION_WORKFLOW_SURVEY.md) | Surveys for OpenShift Virtualization / instance types |
| [DOMAIN_INPUT_YAML.md](DOMAIN_INPUT_YAML.md) | Domain YAML under **`projects/*/domain/`** |
| [GIT_WEBHOOK_EDA.md](GIT_WEBHOOK_EDA.md) | Git webhook → EDA / SCM sync / gated workflow |

## Repository root

| Document | Purpose |
|----------|---------|
| [../README.md](../README.md) | Layout, basic three-playbook workflow, Controller checklist |
| [../workshop/CLIENT_RUNBOOK.md](../workshop/CLIENT_RUNBOOK.md) | Operator steps: Hub, workflows, email approval |
| [../workshop/use-cases/README.md](../workshop/use-cases/README.md) | UC-01–UC-07 index |

## Scripts (referenced by docs)

| Script | Purpose |
|--------|---------|
| `scripts/hub-sync-community-from-requirements.sh` | Mirror **`collections/requirements.yml`** into Hub **community** |
| `scripts/hub-sync-rh-certified-from-secret.sh` | Apply offline token from **`rh-hub-offline-token`** and sync **rh-certified** |
