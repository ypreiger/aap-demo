# Documentation index (`aap-demo`)

All **narrative guides** live here. Filenames use **`NN_` prefixes** so sort order matches the recommended read path. The repository **[`README.md`](../README.md)** lists repo layout; **this file** is the documentation map.

**Workshop** operator steps (**[`../workshop/CLIENT_RUNBOOK.md`](../workshop/CLIENT_RUNBOOK.md)**, **[`../workshop/PLAN.md`](../workshop/PLAN.md)**) link into these pages instead of repeating procedures.

---

## Ordered guides (`01`–`10`)

| # | File | Purpose |
|---|------|---------|
| **01** | [01_INSTALL_OPENSHIFT.md](01_INSTALL_OPENSHIFT.md) | Greenfield cluster: operator → `AnsibleAutomationPlatform` → Hub → Controller → Tower CRs → credentials |
| **02** | [02_COLLECTION_HUB.md](02_COLLECTION_HUB.md) | Automation Hub: Community vs Published, **`requirements.yml`** mirror, rh-certified token, scripts |
| **03** | [03_COLLECTION_CONTROLLER.md](03_COLLECTION_CONTROLLER.md) | Controller: Galaxy/Hub credential on organization, collection download, project sync, EE |
| **04** | [04_COLLECTION_REFERENCE.md](04_COLLECTION_REFERENCE.md) | Galaxy collections this repo uses; EE / pinning notes |
| **05** | [05_LIGHTSPEED_OPENAPI.md](05_LIGHTSPEED_OPENAPI.md) | **Lightspeed:** **`chatbot_url`** / **`chatbot_token`** (LLM API), vs Controller API token; troubleshooting |
| **06** | [06_EMAIL_APPROVAL.md](06_EMAIL_APPROVAL.md) | Approval email, **`email-plugin`**, Controller webhooks |
| **07** | [07_EDA_GIT_WEBHOOK.md](07_EDA_GIT_WEBHOOK.md) | Git → `git-webhook-bridge` → EDA + gated workflows |
| **08** | [08_DOMAIN_INPUT.md](08_DOMAIN_INPUT.md) | Domain YAML under **`projects/*/domain/`** |
| **09** | [09_VIRT_WORKFLOW_SURVEY.md](09_VIRT_WORKFLOW_SURVEY.md) | OpenShift Virtualization / workflow survey fields |
| **10** | [10_PROJECTS_GIT_SYNC.md](10_PROJECTS_GIT_SYNC.md) | One Controller **Project** vs many **`projects/<slug>/`** trees |

---

## Use cases (UC-01–UC-07)

Index and per-UC files: **[`../workshop/use-cases/README.md`](../workshop/use-cases/README.md)** (`USECASE_UC*.md` in the same folder).

---

## Workshop vs `documentation/`

| Path | Role |
|------|------|
| **[`../workshop/README.md`](../workshop/README.md)** | What lives under **`workshop/`** (mock infra, scripts, agents) |
| **[`../workshop/CLIENT_RUNBOOK.md`](../workshop/CLIENT_RUNBOOK.md)** | Operator checklist and troubleshooting tables |
| **[`../workshop/PLAN.md`](../workshop/PLAN.md)** | Rollout / verification order after the platform exists |

Technical depth stays in the numbered **`documentation/*.md`** files above to avoid drift.
