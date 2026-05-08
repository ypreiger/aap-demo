# Workshop — multi-domain AAP on OpenShift

Repository root: [`aap-demo`](../README.md).

Operator procedures (templates, Hub, email): **[`CLIENT_RUNBOOK.md`](CLIENT_RUNBOOK.md)**.

## Contents

| Path | Contents |
|------|----------|
| [`CLIENT_RUNBOOK.md`](CLIENT_RUNBOOK.md) | Templates to launch, approvals, Hub collections, Controller execution |
| [`PLAN.md`](PLAN.md) | Rollout and verification order |
| [`agents/`](agents/) | Delegated task prompts (Cursor / automation) |
| [`use-cases/README.md`](use-cases/README.md) | UC-01–UC-07 index |
| [`use-cases/*.md`](use-cases/) | UC-05 Hub/Blue Coat; UC-06 email approval; UC-07 namespace → mail → netpol |
| [`openshift/mock-infra`](openshift/mock-infra) | Mock JSON for F5 / VMware / Blue Coat |
| [`scripts/`](scripts) | Routes, workflow gates, E2E |
| [`git-webhook-bridge/`](git-webhook-bridge) | GitHub `push` → EDA POST + SCM sync + gated workflow |
| [Domain YAML](../documentation/DOMAIN_INPUT_YAML.md) | **`projects/*/domain/`** |

## Verify multi-domain workflow

1. Sync Hub **Community** — **[`documentation/HUB_COLLECTIONS.md`](../documentation/HUB_COLLECTIONS.md)**.
2. Controller collections — **`documentation/CONTROLLER_COLLECTIONS_VISIBILITY.md`**.
3. Run:

```bash
oc apply -k workshop/openshift/mock-infra
oc apply -k aap-yamls/tower/
bash workshop/scripts/run-e2e-multi-domain-workflow.sh
```

If **`workshop_mock_base_url`** is unset, set the survey to the **`workshop-mock-infra`** Route HTTPS origin (scheme + host, no path).
