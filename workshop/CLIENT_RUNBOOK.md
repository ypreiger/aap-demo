# Client runbook — run each use case in Ansible Automation Platform

Canonical repo: **[ypreiger/aap-demo](https://github.com/ypreiger/aap-demo)**.

This guide is for **operators** using **Automation Controller** and **Automation Hub**.

It covers:

- Which workflow template to launch  
- Expected job output  
- Where Hub lists collections (Community vs Published)  
- Blue Coat / ProxySG (mock URI, not a Galaxy collection name)  
- Adding collections and execution environments  
- Email with Approve/Deny links (**`email-plugin`**)

**Per-use-case procedures:** **[`use-cases/README.md`](use-cases/README.md)** (UC-01–UC-07). Each UC file is the step-by-step checklist for that scenario.

---

## 1. What to open in the browser

| Area | Typical path | Notes |
|------|----------------|------|
| **AAP Gateway** | `https://<gateway-host>/` | Single entry; tiles for **Hub**, **Controller**, etc. |
| **Automation Hub — collections** | **`/content/collections`** | Often defaults to **Published** (Red Hat certified). |
| **Automation Controller** | **`/automation-controller/`** or platform-specific link | **Templates** → workflow / job templates |

Use the **cluster / workshop** URL your admin gives you (example host pattern: `demo-aap-aap.apps.<cluster>.dynamic.redhatworkshops.io`).

---

## 2. View collections in Automation Hub (basic use case)

**Goal:** Confirm community collections are present (this repo’s BOM/workshop content uses collections listed in [`collections/requirements.yml`](../collections/requirements.yml)).

### Steps

1. Log into the **gateway** as a user who can open **Automation Hub** (Hub admin is only needed for sync scripts, not for browsing).
2. Open **Automation Hub** → **Collections** (or **`/content/collections`** on the gateway).
3. If the list is **empty**, open the **repository** or **filter** control and select **Community** (wording varies by version: “Community”, “community”, or repository dropdown).
4. You should see namespaces such as **`kubernetes`**, **`community`**, **`vmware`**, **`f5networks`**, etc., matching what was synced from Galaxy.

**Why Published can stay empty:** Certified content comes from the **rh-certified** remote and needs Red Hat subscription / token setup on the platform. The workshop content is satisfied by **Community** collections mirrored into Hub.

**If Community is still empty:** Run **`scripts/hub-sync-community-from-requirements.sh`** (requires **`oc`** and Hub admin credentials). See **[`documentation/HUB_COLLECTIONS.md`](../documentation/HUB_COLLECTIONS.md)**.

**If Published / All is empty but certified content exists:** Sync **`rh-certified`** first (offline token — **[`documentation/HUB_COLLECTIONS.md`](../documentation/HUB_COLLECTIONS.md)** §2), then mirror **`published`** (**§2.6**, script **`scripts/hub-sync-published-mirror-rh-certified.sh`**). Until **`published`** finishes syncing, select repository **`rh-certified`** in Hub.

### What you should see

- Collection **names** and **versions**, with download counts that may be zero in a fresh lab.
- No error banner about “no repositories”.

---

## 3. “Where is the Blue Coat collection?”

**There is no widely used Ansible Galaxy collection named “Blue Coat” or “ProxySG”** for Symantec / Broadcom SGOS the way there is for F5 or VMware. This repository documents that in **[`documentation/ANSIBLE_COLLECTIONS.md`](../documentation/ANSIBLE_COLLECTIONS.md)** (section *Symantec Broadcom ProxySG (“Blue Coat”)*).

What this **workshop** does instead:

- **`workshop-mock-bluecoat`** job template calls **`playbooks/workshop_mock_bluecoat.yml`**, which uses **`ansible.builtin.uri`** against a **mock HTTPS JSON** endpoint (Route **`workshop-mock-infra`**, file **`/bluecoat_health.json`**).
- When you move to **real** ProxySG automation, you typically use **URI** modules, **SSH/expect**, or a **vendor/partner** collection **outside** Galaxy — not something you “find” under Hub’s community list today.

**Hands-on:** Run the full **`workshop-multi-domain`** workflow (section 6); the **Blue Coat** mock step is the last job node and should show **HTTP 200** responses in the job log.

---

## 4. Import or add additional collections

Pick the path that matches your policy.

### A. Collections for **Automation Hub** (browse / `ansible-galaxy` against Hub)

1. Edit **[`collections/requirements.yml`](../collections/requirements.yml)** and add an entry, for example:
   ```yaml
   - name: ansible.posix
     source: https://galaxy.ansible.com
   ```
2. On a machine with **`oc`**, re-sync the **community** repository from that file:
   ```bash
   export HUB_GATEWAY_URL="https://<your-gateway-host>"
   ./scripts/hub-sync-community-from-requirements.sh
   ```
   Details: **[`documentation/HUB_COLLECTIONS.md`](../documentation/HUB_COLLECTIONS.md)**.

### B. Collections for **Automation Controller** job runs (most common in class)

Controller installs collections from **`requirements.yml`** **when the project syncs**, if collection download is enabled and a Galaxy/Hub credential exists on the organization.

1. Follow **[`documentation/CONTROLLER_COLLECTIONS_VISIBILITY.md`](../documentation/CONTROLLER_COLLECTIONS_VISIBILITY.md)** (enable download, org credential, **sync project**).
2. After changing **`collections/requirements.yml`** in Git, **update the project** in Controller (**Projects** → **Sync**).

### C. Collections **baked into an Execution Environment**

For production-style labs, build an EE with **`ansible-builder`** using the same requirements file — see **[`execution-environment/README.md`](../execution-environment/README.md)** and **`./scripts/verify-collections-and-ee.sh`**.

---

## 5. Email approval (Approve and Deny buttons in email)

**You get email only if** the **`email-plugin`** service is deployed **and** a **webhook notification** is attached to **that workflow’s Approval channel** **and** SMTP is enabled (e.g. Gmail app password).

### 5.1 Default setup in the docs (workflow **`bom-project-deploy`**)

The playbook **[`email-plugin/playbooks/register_controller_webhook_notification.yml`](../email-plugin/playbooks/register_controller_webhook_notification.yml)** defaults to **`workflow_name=bom-project-deploy`**. So the **reliable** demo for **clickable Approve/Deny** is:

| Step | Action |
|------|--------|
| 1 | Deploy **`email-plugin`**: **[`email-plugin/README.md`](../email-plugin/README.md)** — `SMTP_PASSWORD='...' DISABLE_SMTP=false ./email-plugin/scripts/deploy-email-plugin.sh` |
| 2 | Register webhook: **[`documentation/CONFIGURE_AAP_APPROVAL_EMAIL.md`](../documentation/CONFIGURE_AAP_APPROVAL_EMAIL.md)** — `ansible-playbook email-plugin/playbooks/register_controller_webhook_notification.yml` with `controller_host`, `controller_oauth_token`, `webhook_target_url` |
| 3 | Confirm **Controller** → **Administration** → **Settings** → **System** → **Base URL of the service** is your real Controller URL |

### 5.2 Launch the workflow (you)

1. Open **Automation Controller** → **Templates**.
2. Select workflow template **`bom-project-deploy`** → **Launch**.
3. Complete the **survey** (**`project_name`** at minimum, e.g. **`proj1`**; other fields are VM sizing — defaults are usually fine for a smoke test).
4. **Watch:** first job **`bom-project-foundation`** runs; then the workflow pauses on **`bom-approve-before-vms`**.

### 5.3 Approve or deny

**Option A — Email (buttons)**  
Within a few minutes (SMTP + spam folders), the approver inbox should receive a message whose **Approve** and **Deny** links hit the **`email-plugin`** Route. Click **Approve** to resume the workflow to **`bom-project-vms`**.

**Option B — Controller UI**  
**Jobs** → open the workflow job → pending **Approval** → **Approve** / **Deny**.

### What you should see

- Workflow status moves from **Pending** → **Successful** after approval (unless a later job fails).
- After approval: job template **`bom-project-vms`** runs and attempts to create **VirtualMachine** resources (cluster must have OpenShift Virtualization / capacity).

**If no email arrives:** plugin not deployed, **`DISABLE_SMTP`**, wrong **`DEFAULT_TO_EMAIL`**, SMTP blocked egress, webhook not attached to **`bom-project-deploy`**, or message in spam. See **[`documentation/CONFIGURE_AAP_APPROVAL_EMAIL.md`](../documentation/CONFIGURE_AAP_APPROVAL_EMAIL.md)** troubleshooting table.

### 5.4 Minimal email E2E — **`email-e2e-ns-netpol`** (namespace → approve mail → deny‑all NetworkPolicy)

**Goal:** Run a **small** workflow that creates only a **Namespace** (survey **`target_namespace`**), stops on **`bom-approve-before-vms`**, sends **Approve / Deny** mail when **`email-plugin`** is wired for **this** workflow, then applies a deny‑all **`NetworkPolicy`** after approval (**no VMs**).

| Step | Action |
|------|--------|
| 1 | Presenter: **`oc apply -k aap-yamls/tower/`** (Tower CRs include workflow **`email-e2e-ns-netpol`**) |
| 2 | Presenter: **`bash scripts/register-webhook-email-e2e-ns-netpol.sh`** (after **`Secret/aap-controller-api`** exists and **`email-plugin`** Route is up) |
| 3 | **Projects** → **AAP Demo (GitHub)** → **Sync** so playbooks **`playbooks/email_e2e_*.yml`** are on disk |
| 4 | **Templates** → **`email-e2e-ns-netpol`** → **Launch** → set **Target namespace** |
| 5 | Approve from mail (or Controller UI); confirm **`NetworkPolicy`** **`email-e2e-deny-all`** in that namespace |

Full steps and cleanup: **[`use-cases/UC-07-email-e2e-namespace-netpol.md`](use-cases/UC-07-email-e2e-namespace-netpol.md)**.

### 5.5 Same email for **`workshop-multi-domain`**

The default registration step **does not** attach the webhook to **`workshop-multi-domain`**. Run the same playbook again with an explicit workflow name (and a **distinct** notification name so you do not fight the previous association):

```bash
ansible-playbook email-plugin/playbooks/register_controller_webhook_notification.yml \
  -e controller_host="$CH" \
  -e controller_oauth_token="$TK" \
  -e webhook_target_url="$WH" \
  -e workflow_name=workshop-multi-domain \
  -e notification_name=workshop-email-plugin-webhook
```

Then launch **`workshop-multi-domain`**; when **`bom-approve-before-vms`** is reached inside that workflow, the webhook should fire the same way.

---

## 6. Workflow workshop-multi-domain step by step

**Goal:** Single survey drives **foundation → approval → VMs → netpol audit → mock F5 → mock VMware → mock Blue Coat**.

### What `workshop_mock_base_url` is

Survey field **Mock integrations base URL** passes **`extra_vars`** **`workshop_mock_base_url`** into the playbook jobs under the mock (**F5 / VMware / Blue Coat**) templates. Its value must be the **HTTPS origin** served by **`workshop-mock-infra`** — the **scheme + host**, **no trailing slash**, **no path**. Playbooks suffix paths such as **`/f5_pool.json`**, **`/vmware_guests.json`**, **`/bluecoat_health.json`**.

Presenter deploy (**edge TLS Route** exposes nginx):

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
oc apply -k workshop/openshift/mock-infra
bash workshop/scripts/resolve-mock-route.sh   # prints https://...
```

Example on a sandbox cluster *(replace with your route host)*:

`https://workshop-mock-infra-aap.apps.<your-cluster-domain>`

### Prerequisites

- **Collections:** Hub **Community** visible (section 2); Controller **collections download** wired ([`documentation/CONTROLLER_COLLECTIONS_VISIBILITY.md`](../documentation/CONTROLLER_COLLECTIONS_VISIBILITY.md)).
- **Mock JSON Route:** Apply **`workshop/openshift/mock-infra`** so Route **`workshop-mock-infra`** exists.
- **Survey URL:** Obtain the HTTPS base (**no trailing slash**), e.g.:
  ```bash
  bash workshop/scripts/resolve-mock-route.sh
  ```
  Paste into survey field **Mock integrations base URL**.

### Steps (you)

1. **Automation Controller** → **Templates** → **`workshop-multi-domain`** → **Launch**.
2. Survey:
   - **Project name (BOM path):** e.g. **`proj1`**
   - **Mock integrations base URL:** **`https://<workshop-mock-infra-route-host>`**
3. Submit; monitor **Jobs** as the workflow advances.

### Node order & what you should see

| Order | Job / gate | Expected |
|------|-------------|----------|
| 1 | **`bom-project-foundation`** | Namespace / BOM artefacts / netpol baseline from Git `projects/<project>/bom/` |
| 2 | **`bom-approve-before-vms`** | **Approval gate** — stop until approved (section 5) |
| 3 | **`workshop-bom-project-vms`** | **VirtualMachine** CRs created (survey/vars from workflow) |
| 4 | **`workshop-networkpolicy-audit`** | Validation + annotation on namespace |
| 5 | **`workshop-mock-f5`** | Log shows **`uri`** GET to **`.../f5_pool.json`** |
| 6 | **`workshop-mock-vmware`** | Log shows GET to **`.../vmware_guests.json`** |
| 7 | **`workshop-mock-bluecoat`** | Log shows GET to **`.../bluecoat_health.json`** |

Failures usually mean: wrong **`workshop_mock_base_url`**, mock Route missing, Virt not installed, insufficient quota, expired cluster credential **`openshift-bom-target`**, or approval timed out/denied.

---

## 7. Related documents

| Topic | Doc |
|--------|-----|
| UC-07 email E2E (namespace + netpol) | [`use-cases/UC-07-email-e2e-namespace-netpol.md`](use-cases/UC-07-email-e2e-namespace-netpol.md) |
| Hub empty UI | [`documentation/HUB_COLLECTIONS.md`](../documentation/HUB_COLLECTIONS.md) |
| Controller + `requirements.yml` | [`documentation/CONTROLLER_COLLECTIONS_VISIBILITY.md`](../documentation/CONTROLLER_COLLECTIONS_VISIBILITY.md) |
| Collection list & EE | [`documentation/ANSIBLE_COLLECTIONS.md`](../documentation/ANSIBLE_COLLECTIONS.md) |
| Email plugin deploy + webhook | [`email-plugin/README.md`](../email-plugin/README.md), [`documentation/CONFIGURE_AAP_APPROVAL_EMAIL.md`](../documentation/CONFIGURE_AAP_APPROVAL_EMAIL.md) |
| Presenter rollout order | [`PLAN.md`](PLAN.md) |
