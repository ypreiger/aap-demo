# UC-05 — Inspect collections in Automation Hub (incl. Blue Coat / ProxySG)

## Goal

- Locate collections in **Automation Hub** (Community vs Published).
- Explain why **ProxySG (“Blue Coat”)** does not appear as a standard Galaxy collection like F5 or VMware.

## Prerequisites

- Log in to the **AAP gateway** (Hub + Controller).
- **Community** repository synced: **`../../scripts/hub-sync-community-from-requirements.sh`** and **`../../documentation/02_COLLECTION_HUB.md`**.
- **Published** optional: **`../../documentation/02_COLLECTION_HUB.md`** §2 (offline token).
- Optional: **`../../documentation/04_COLLECTION_REFERENCE.md`** (ProxySG patterns).

---

## Instructions — inspect collections

1. From the gateway home page, open **Automation Hub**.
2. Open **Collections** (path is often **`/content/collections`** on the gateway, e.g. **Content → Collections**, depending on AAP layout).
3. Find the **repository / filter / pipeline** control (dropdown or tabs labelled **Published**, **Community**, **Red Hat Certified**, or similar — wording varies by version).
4. Select **Community** (or the repository backed by **`galaxy.ansible.com`** mirrored into Hub).

### What you should see (examples)

Namespaces and collection names aligned with **`../../collections/requirements.yml`** mirror, for example:

| Namespace / collection | Typical note |
|------------------------|---------------|
| **kubernetes**/… | BOM / **`kubernetes.core`** |
| **community**/kubevirt , **community**/vmware … | Supporting modules |
| **vmware**/… | **`vmware.vmware_rest`** path |
| **f5networks**/… | **`f5networks.f5_modules`** |

**Download counts may be zero** in a demo cluster; counts are normal after real usage.

5. Switch the filter to **Published** / **certified** / **rh-certified**.

### What you should see on Published

- Often **few or zero** rows on a sandbox until **rh-certified** is synced **with Red Hat entitlement + token**.
- Empty **Published** is **normal** here; labs rely on **Community** mirrored from Galaxy.

---

## Blue Coat / ProxySG — where is “the Blue Coat collection”?

6. Stay in Hub **Collections** search and query **bluecoat**, **proxysg**, **symantec**, **broadcom**.

### What you should see

- No **maintained Ansible Galaxy-style collection** for ProxySG that matches what F5 or VMware collections provide. This is expected.

### Why this workshop still mentions Blue Coat

- Day-2 “Blue Coat” in this repo is implemented as **`ansible.builtin.uri`** against a **mock JSON** **`/bluecoat_health.json`** (**Route `workshop-mock-infra`**) inside workflow **`workshop-multi-domain`** — see **[`UC-03-mock-f5-vmware-bluecoat.md`](USECASE_UC03_mock_f5_vmware_bluecoat.md)**.
- Patterns for production automation (URI vs SSH/`expect`, vendor bundles) live in **`../../documentation/04_COLLECTION_REFERENCE.md`** (ProxySG subsection).

---

## Optional — API sanity check

From a terminal (replace gateway host; use Hub admin `-u admin:PASSWORD` only if anonymous browse is insufficient):

```bash
GATEWAY="https://<your-aap-gateway-host>"
curl -sk "${GATEWAY}/api/galaxy/v3/plugin/ansible/content/community/collections/index/?limit=20" \
  | python3 -c "import sys,json; j=json.load(sys.stdin); print('count=', j['meta'].get('count'))"
curl -sk "${GATEWAY}/api/galaxy/v3/plugin/ansible/content/published/collections/index/?limit=5" \
  | python3 -c "import sys,json; j=json.load(sys.stdin); print('published count=', j['meta'].get('count'))"
```

---

## Troubleshooting

| Symptom | Action |
|---------|--------|
| **Community empty** | Run **`hub-sync-community-from-requirements.sh`** — **`../../documentation/02_COLLECTION_HUB.md`**. |
| **Only Published visible** | Change UI filter/repo to **Community**. |
| **Looking for ProxySG Ansible modules in Hub** | Use **mock playbooks / URI** (**UC-03**) or **`04_COLLECTION_REFERENCE.md`** alternatives; not Hub search. |

## Success criteria

- You locate **Community** collections that match this demo’s **`collections/requirements.yml`**.
- You can explain why **Published** may be empty and why **Blue Coat** is **not** a standard Hub collection listing.
