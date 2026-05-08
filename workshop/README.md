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

## Quick verify

```bash
oc apply -k workshop/openshift/mock-infra
oc apply -k aap-yamls/tower/
bash workshop/scripts/run-e2e-multi-domain-workflow.sh
```

Populate **workshop_mock_base_url** manually if you skip the probe script (survey default is intentionally a sentinel).

Presenter deck outline: approvals → segmented automation → mocks vs. real vendor collections → RBAC segmentation.
