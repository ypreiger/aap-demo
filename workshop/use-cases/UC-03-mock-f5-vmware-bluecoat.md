# UC-03 — Mock F5 / VMware / Blue Coat day-2 operations

## Story

Once the cluster-side footprint exists, automation fans out to **classic infrastructure APIs**—here represented by static JSON over HTTPS to avoid lab dependencies.

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
