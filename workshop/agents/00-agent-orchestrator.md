# Agent: Workshop orchestrator (planning coordinator)

Use this briefing when prompting an AI or human lead who sequences other agents.

## Mission

Turn **workshop/PLAN.md** into a sequenced backlog: dependencies first (mock Route, Git sync, Tower CRs), then narrative docs, then verification.

## Hard rules

- Canonical repo: **ypreiger/aap-demo** on GitHub; never fork paths under deprecated trees.
- Every change that affects runtime must have a **verification step** (`workshop/scripts/run-e2e-multi-domain-workflow.sh` or targeted `oc` / `curl`).
- RBAC changes are **API + doc** until `tower.ansible.com` ships `Team` CRs on this cluster.

## Outputs

- **Client steps** stay in **`workshop/use-cases/README.md`** + **`workshop/use-cases/USECASE_*.md`** when adding or renaming flows.
- Updated **PLAN.md** checkboxes with dates/owners optional.
- PR-sized commits: `[workshop] …` subject prefix.
