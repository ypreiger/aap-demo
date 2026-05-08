# Multi-domain Infrastructure Workshop — AAP on OpenShift

Companion code lives alongside the Ansible project under [`aap-demo`](../README.md).

## Contents

| Path | Meaning |
|------|---------|
| [`PLAN.md`](PLAN.md) | Consolidated rollout & verification plan |
| [`agents/`](agents/) | System prompts for delegated “agents” (Cursor / humans) |
| [`use-cases/`](use-cases/) | Short domain narratives + success criteria |
| [`openshift/mock-infra`](openshift/mock-infra) | nginx JSON mocks (F5 / VMware / Blue Coat) |
| [`scripts/`](scripts) | Resolve Route host, approve workflow gates, **run E2E** |
| [`git-webhook-bridge/`](git-webhook-bridge) | GitHub `push` → optional **EDA POST** + Controller SCM sync + **approved** workflow launch |
| [Domain YAML inputs](../documentation/DOMAIN_INPUT_YAML.md) | Firewall / F5 / Blue Coat declarations under **`projects/*/domain/`** |

## Quick verify

**Prerequisite:** **`community`** Hub content synced if you browse collections (**[documentation/HUB_COLLECTIONS.md](../documentation/HUB_COLLECTIONS.md)**); Controller still needs **`documentation/CONTROLLER_COLLECTIONS_VISIBILITY.md`** for Galaxy/EE semantics.

```bash
oc apply -k workshop/openshift/mock-infra
oc apply -k aap-yamls/tower/
bash workshop/scripts/run-e2e-multi-domain-workflow.sh
```

Populate **workshop_mock_base_url** manually if you skip the probe script (survey default is intentionally a sentinel).

Presenter deck outline: approvals → segmented automation → mocks vs. real vendor collections → RBAC segmentation.
