# Automation Hub: collections page looks empty (gateway UI)

Canonical repo: [https://github.com/ypreiger/aap-demo](https://github.com/ypreiger/aap-demo).

On a fresh **Ansible Automation Platform** deployment, **Automation Hub** may show **no collections** on the gateway path **`/content/collections`** (for example  
[https://demo-aap-aap.apps.cluster-jx4b7.dynamic.redhatworkshops.io/content/collections](https://demo-aap-aap.apps.cluster-jx4b7.dynamic.redhatworkshops.io/content/collections)) even though Hub is healthy.

This is usually one of the following:

1. **UI filter: Published vs Community** — the page often defaults to **certified / published** content. **Community** collections only appear after the **community** repository has been synced from `galaxy.ansible.com`, and you must **select the Community repository** (or equivalent filter) in the UI.
2. **Community sync never ran or was rejected** — current **Galaxy NG / Pulp** builds can **refuse** to sync from `galaxy.ansible.com` **without** a **`requirements_file`** on the **community** collection remote. The API error is along the lines of: *“Syncing content from galaxy.ansible.com without specifying a requirements file is not allowed.”*
3. **Red Hat certified content** — the **rh-certified** / **published** pipeline needs a valid **Red Hat Automation Hub** token on the remote and a successful **rh-certified** sync. Until then, **published** counts can stay at **0** even when **community** is populated.

This repository’s collection list for workshops and BOM content is defined in [`collections/requirements.yml`](../collections/requirements.yml). That file is the single source of truth for **which** community collections to mirror into Hub for this demo.

---

## Quick fix (automated)

From a machine with **`oc` logged into the cluster** (namespace **`aap`** by default) and **`curl`**, **`jq`** on `PATH`:

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
export HUB_GATEWAY_URL="https://<your-aap-gateway-host>/"
./scripts/hub-sync-community-from-requirements.sh
```

The script:

1. Reads **Hub admin** password from the OpenShift **`Secret`** **`demo-aap-hub-admin-password`** (override with **`HUB_ADMIN_SECRET`**).
2. **`PATCH`**es the Pulp **`community`** collection remote so **`requirements_file`** matches **`collections/requirements.yml`**.
3. **`POST`**s a **`community`** repository sync and optionally waits until the Pulp task completes (**`WAIT_FOR_SYNC=true`** by default).

**Idempotent:** safe to **re-run** whenever you change **`collections/requirements.yml`** or Hub was reset. Re-running triggers another incremental sync (not a full cluster “cleanup”; see below).

**Fast path (fire-and-forget):**

```bash
WAIT_FOR_SYNC=false ./scripts/hub-sync-community-from-requirements.sh
```

---

## Verify (API — same auth as Hub admin UI)

Substitute **`$GATEWAY`**, **`$USER`**, **`$PASS`** (or `-u admin:$(oc …)`):

```bash
# Community repo index — should show meta.count > 0 after a successful sync
curl -sk -u "$USER:$PASS" \
  "${GATEWAY}/api/galaxy/v3/plugin/ansible/content/community/collections/index/?limit=5"

# Published / certified index — often 0 until rh-certified sync + entitlement
curl -sk -u "$USER:$PASS" \
  "${GATEWAY}/api/galaxy/v3/plugin/ansible/content/published/collections/index/?limit=5"
```

Then open **`/content/collections`** again and switch the UI to **Community** content if you still see an empty **Published** view.

---

## Relation to Automation Controller

Controller **does not** automatically populate Hub. For job templates pulling collections from Galaxy or Hub credentials, see:

- [**Controller collections visibility**](CONTROLLER_COLLECTIONS_VISIBILITY.md)
- [**Ansible collections in this repo**](ANSIBLE_COLLECTIONS.md)

---

## Cleanup and re-run semantics

| Action | Meaning |
|--------|--------|
| **Re-run** `./scripts/hub-sync-community-from-requirements.sh` | **Supported** — updates `requirements_file` if the YAML changed and starts a new sync task. |
| **Remove demo collections from Hub** | **Not scripted here** — purging repositories is disruptive and rarely needed for workshop resets; prefer **re-deploying** the lab or opening a ticket for your platform team if you must reclaim storage. |

Workshop teardown for **jobs / workflows / mock routes** continues to live under **`workshop/scripts/`** and **`scripts/workshop-aap-cleanup-unused.sh`**, not Hub content.
