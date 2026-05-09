# UC-03 — Mock F5 / VMware / Blue Coat day-2 operations

## Goal

Run mock **F5 / VMware / Blue Coat** jobs over **`ansible.builtin.uri`** against JSON served by **`workshop-mock-infra`**.

## Prerequisites

**`../PLAN.md`**, Route **`workshop-mock-infra`**, survey **`workshop_mock_base_url`** set (see UC-01).

ProxySG / Blue Coat: **[`UC-05-inspect-hub-collections-bluecoat.md`](USECASE_UC05_inspect_hub_collections_bluecoat.md)** (Hub search vs URI mock).

---

## Instructions (step-by-step in AAP)

1. Run **`workshop-multi-domain`** through **UC-01** (approval + VMs + netpol stage per **UC-02**), **or** jump to a workflow job already past **`workshop-networkpolicy-audit`**.
2. On the workflow graph, open jobs in order:
   - **`workshop-mock-f5`**
   - **`workshop-mock-vmware`**
   - **`workshop-mock-bluecoat`**
3. For each job, open **Output** and confirm **`ansible.builtin.uri`** **GET** against your survey base + path:
   - **`{workshop_mock_base_url}/f5_pool.json`**
   - **`{workshop_mock_base_url}/vmware_guests.json`**
   - **`{workshop_mock_base_url}/bluecoat_health.json`**
4. Status should be **HTTP 200** (or equivalent success in log). **`workshop_mock_bluecoat.yml`** respects **`workshop_bluecoat_skip: true`** when you need to bypass Blue Coat demo.

### What you should see

| Job | Evidence in log |
|-----|----------------|
| **`workshop-mock-f5`** | JSON resembling pool / member structure from nginx mock **`/f5_pool.json`** |
| **`workshop-mock-vmware`** | Guest-style JSON from **`/vmware_guests.json`** |
| **`workshop-mock-bluecoat`** | Health-ish JSON from **`/bluecoat_health.json`** (**not** a Galaxy **`bluecoat`** collection) |

### Quick sanity check outside Controller

Replace **`BASE`** with your **`workshop_mock_base_url`**:

```bash
curl -sk "${BASE}/f5_pool.json" | head -c 200
curl -sk "${BASE}/bluecoat_health.json" | head -c 200
```

---

## Endpoints (Route `workshop-mock-infra`)

| File | Simulated domain |
|------|------------------|
| `/f5_pool.json` | BIG-IP pool + members |
| `/vmware_guests.json` | vCenter-style inventory |
| `/bluecoat_health.json` | ProxySG management health |

## Playbooks

- `../../playbooks/workshop_mock_f5.yml`
- `../../playbooks/workshop_mock_vmware.yml`
- `../../playbooks/workshop_mock_bluecoat.yml` (`workshop_bluecoat_skip: true` to bypass)

## Graduation path

Swap **`uri`** tasks for **`f5networks.f5_modules`**, **`community.vmware`**, real ProxySG automation once credentials exist — Galaxy collections for F5/VMware live in **`../../collections/requirements.yml`**; ProxySG alternatives in **`../../documentation/04_COLLECTION_REFERENCE.md`**.

## See also

- **[`../CLIENT_RUNBOOK.md`](../CLIENT_RUNBOOK.md)** §6 — node order (**ws-f5** → **ws-vmware** → **ws-bluecoat**).
