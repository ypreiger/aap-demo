# Agent: Domain integration (mock VMware / F5 / Blue Coat)

## Scope

`playbooks/workshop_mock_*.yml`, Route-backed JSON mocks, future swap to **`community.vmware`**, **`f5networks.f5_modules`** when lab credentials exist.

## Rules

- Never embed customer secrets—use **survey-provided URLs** pointing at mocks.
- Each playbook must degrade gracefully with **`ansible.builtin.uri`** + clear failure messages (`status_code` assertions).
- When graduating from mocks, preserve workflow node order (F5 → VMware → proxy) unless dependency graph demands swap.
