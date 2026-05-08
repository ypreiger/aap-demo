# Automation Hub: collections and sync

Repository: [ypreiger/aap-demo](https://github.com/ypreiger/aap-demo).

## Why `/content/collections` looks empty

Three separate causes:

1. **UI repository filter**  
   The page often defaults to **Published** (Red Hat certified). **Community** content appears only after you select the **Community** repository (or equivalent filter) in the Hub UI.

2. **Community repository never synced**  
   Galaxy NG / Pulp can reject syncing `galaxy.ansible.com` without a **`requirements_file`** on the **community** collection remote. Typical API message: *Syncing content from galaxy.ansible.com without specifying a requirements file is not allowed.*

3. **Published repository never synced**  
   Certified collections require a valid **offline token** on the **`rh-certified`** remote and a completed sync of the **`rh-certified`** repository. Until then, **Published** stays at count **0** even when **Community** is populated.

Allow-listed community collections for this repository are defined in [`collections/requirements.yml`](../collections/requirements.yml).

---

## 1. Sync Community collections

### Prerequisites

- `oc` logged into the cluster (namespace **`aap`** by default)
- `curl`, `jq`
- Hub admin password in OpenShift Secret **`demo-aap-hub-admin-password`** (override with **`HUB_ADMIN_SECRET`**)

### Command

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
export HUB_GATEWAY_URL="https://<your-aap-gateway-host>"
./scripts/hub-sync-community-from-requirements.sh
```

### What the script does

1. Reads Hub admin password from the Secret above.
2. **PATCH**es the Pulp **`community`** collection remote so **`requirements_file`** matches **`collections/requirements.yml`**.
3. **POST**s a **`community`** repository sync.
4. Waits for the Pulp task to finish (**`WAIT_FOR_SYNC=true`** by default).

Re-running is safe after you change **`collections/requirements.yml`** or reset Hub.

Fast start without waiting for task completion:

```bash
WAIT_FOR_SYNC=false ./scripts/hub-sync-community-from-requirements.sh
```

### Verify (API)

```bash
GATEWAY="https://<your-aap-gateway-host>"
USER="admin"
PASS="$(oc get secret -n aap demo-aap-hub-admin-password -o jsonpath='{.data.password}' | base64 -d)"

curl -sk -u "${USER}:${PASS}" \
  "${GATEWAY}/api/galaxy/v3/plugin/ansible/content/community/collections/index/?limit=5" \
  | jq '.meta.count'
```

Expect **`count`** greater than **0** after a successful sync.

---

## 2. Published / Red Hat certified collections (offline token)

Published content is fetched from Red Hat using an **offline token** from the Hybrid Cloud Console.

### 2.1 Obtain the token

1. Open [https://console.redhat.com/](https://console.redhat.com/) and sign in with an account that has **Ansible Automation Platform** entitlement.
2. Go to **Ansible Automation Platform** → **Automation Hub**, or open directly:  
   [https://console.redhat.com/ansible/automation-hub/token/](https://console.redhat.com/ansible/automation-hub/token/)
3. Under **Offline token**, generate or reveal the token and copy it.
4. Record the **sync URL** shown for certified content (same page); it must match the **`rh-certified`** remote URL in Hub (**`https://console.redhat.com/api/automation-hub/content/published/`** unless your platform team specifies otherwise).

Tokens can expire after long inactivity. Regenerate if sync fails with authentication errors.

### 2.2 Store the token in OpenShift

Replace `<OFFLINE_TOKEN>` with the value from the console (do not commit tokens to Git):

```bash
oc create secret generic rh-hub-offline-token -n aap \
  --from-literal=token='<OFFLINE_TOKEN>' \
  --dry-run=client -o yaml | oc apply -f -
```

### 2.3 Apply the token to Hub and sync

From the repository root:

```bash
export HUB_GATEWAY_URL="https://<your-aap-gateway-host>"
./scripts/hub-sync-rh-certified-from-secret.sh
```

This script:

1. Reads **`token`** from **`Secret/rh-hub-offline-token`** in namespace **`aap`**.
2. **PATCH**es the Pulp collection remote named **`rh-certified`** (sets **`token`**).
3. **POST**s a sync on the **`rh-certified`** Ansible repository.

The first certified sync can run for a long time. Watch **Automation Hub → Tasks** (or poll Pulp tasks via API) until completion.

### 2.4 Verify Published content

```bash
curl -sk -u "${USER}:${PASS}" \
  "${GATEWAY}/api/galaxy/v3/plugin/ansible/content/published/collections/index/?limit=5" \
  | jq '.meta.count'
```

### 2.5 Manual configuration (UI)

If you do not use the script:

1. **Automation Hub** → **Remotes** (or **Remote repositories**).
2. Open **`rh-certified`**.
3. Set **URL** to the Red Hat Automation Hub published API URL (see console).
4. Set **Token** to the offline token.
5. Save.
6. Open **Repositories**, select the repository backed by **`rh-certified`** (often named **`rh-certified`** or aligned with **Published** in your build), run **Sync**.

Exact menu labels depend on AAP version; see *Red Hat Ansible Automation Platform* documentation: search for **configure rh-certified remote**.

---

## 3. Hub UI: browse collections

1. Log in to the **AAP gateway**.
2. Open **Automation Hub** → **Collections** (`/content/collections`).
3. Use the repository or filter control:
   - **Community** — mirrored Galaxy collections after §1.
   - **Published** — Red Hat certified content after §2.

---

## 4. Automation Controller

Controller does not populate Hub. For job templates that install collections from Galaxy or Hub, see:

- [CONTROLLER_COLLECTIONS_VISIBILITY.md](CONTROLLER_COLLECTIONS_VISIBILITY.md)
- [ANSIBLE_COLLECTIONS.md](ANSIBLE_COLLECTIONS.md)

---

## 5. Re-run and cleanup

| Action | Result |
|--------|--------|
| Re-run `./scripts/hub-sync-community-from-requirements.sh` | Updates **`requirements_file`** if YAML changed; starts a new community sync. |
| Re-run `./scripts/hub-sync-rh-certified-from-secret.sh` | Refreshes remote token from Secret and starts rh-certified sync. |
| Purge Hub repositories | Not scripted here; coordinate with platform admins if storage must be reclaimed. |

Workshop cleanup for jobs and Routes remains under **`workshop/scripts/`** and **`scripts/workshop-aap-cleanup-unused.sh`**.
