# UC-03 — Mock F5 / VMware / Blue Coat day-2 operations

## Story

Once the cluster-side footprint exists, automation fans out to **classic infrastructure APIs**—here represented by static JSON over HTTPS to avoid lab dependencies.

## Prerequisites

**`../PLAN.md`**, mock Route **`workshop-mock-infra`**, collections per **[`../../documentation/HUB_COLLECTIONS.md`](../../documentation/HUB_COLLECTIONS.md)**.

## Run this in AAP

**`workshop-mock-f5`**, **`workshop-mock-vmware`**, **`workshop-mock-bluecoat`** run in order inside **`workshop-multi-domain`**. Steps and expected log excerpts: **[`../CLIENT_RUNBOOK.md` §6](../CLIENT_RUNBOOK.md#6-workflow-workshop-multi-domain-step-by-step)**.

**Blue Coat collection:** there is no standard Galaxy collection for ProxySG — see **[`../CLIENT_RUNBOOK.md` §3](../CLIENT_RUNBOOK.md#3-where-is-the-blue-coat-collection)**.

## Endpoints (Route `workshop-mock-infra`)

| File | Simulated domain |
|------|------------------|
| `/f5_pool.json` | BIG-IP pool + members |
| `/vmware_guests.json` | vCenter-style inventory |
| `/bluecoat_health.json` | ProxySG management health |

## Playbooks

- `workshop_mock_f5.yml`
- `workshop_mock_vmware.yml`
- `workshop_mock_bluecoat.yml` (set `workshop_bluecoat_skip: true` to bypass)

## Graduation path

Swap URI tasks for **`f5networks.f5_modules`**, **`community.vmware`**, real ProxySG automation once credentials exist.
