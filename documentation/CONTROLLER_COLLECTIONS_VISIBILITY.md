# Seeing collections in Automation Controller (AAP / AWX)

Canonical repo: [https://github.com/ypreiger/aap-demo](https://github.com/ypreiger/aap-demo).

Controller does **not** show a separate “Collections” browser for everything on Galaxy. What you should expect:

- After a **successful project sync**, collections from this repo’s [`collections/requirements.yml`](../collections/requirements.yml) are installed under the project cache (for example under `collections/ansible_collections` next to the checked-out project). Job output and project **Update** logs should include `ansible-galaxy collection install` activity.
- **Job templates** resolve collections from the **Execution Environment** image **and** from the **project’s** installed collections (see product docs for precedence in your version).

If collections “are not there,” it is usually one of: **collection download disabled globally**, **no Galaxy / Automation Hub credential on the organization**, **project never synced successfully**, or the **EE** you selected does not contain the modules you expect.

---

## 1. Enable collection download (global)

**UI:** **Settings** → **Automation Execution** → **Jobs** → enable **Enable Collection(s) Download**.

This maps to the Controller setting **`AWX_COLLECTIONS_ENABLED`** (boolean). It must be **true** for SCM projects to run the **`install_collections`** phase during project updates.

---

## 2. Galaxy or Automation Hub credential on the **organization**

Collections are fetched using **organization-level** Galaxy credentials (ordered list). Your SCM project uses the credentials attached to its **organization** (for example **Default**).

**UI (typical):**

1. **Credentials** → **Add** → type **Ansible Galaxy/Automation Hub API Token**.
2. Set **Galaxy Server URL**:
   - Public Galaxy: `https://galaxy.ansible.com/`
   - **Red Hat Automation Hub** (subscribers): use the URL from your hub’s UI / docs (often under `/api/galaxy/content/...`).
3. **API token:** optional for anonymous public Galaxy within rate limits; **required** for private hub or higher limits.
4. **Organizations** → open your org (**Default**) → **Galaxy credentials** → add the new credential and put it **first** if you use multiple sources.

---

## 3. Sync the Git project

**Projects** → select **AAP Demo (GitHub)** (or your project) → **Sync** / **Update**.

Open the latest **Project Update** job → **Output**: confirm tasks tagged with collection install (for example `install_collections`) and no Galaxy auth errors.

---

## 4. Execution Environment (optional but common)

For **repeatable** jobs, many teams **bake** collections into a **custom EE** using [`execution-environment/`](../execution-environment/) and point job templates at that image. That path does not replace project sync requirements if you rely on **dynamic** install from `requirements.yml`; it **does** give you a known-good image if project-side install is disabled or blocked.

Details: [`documentation/ANSIBLE_COLLECTIONS.md`](ANSIBLE_COLLECTIONS.md).

---

## 5. GitOps / API automation

`AnsibleProject` ([`aap-yamls/tower/ansibleproject-aap-demo.yaml`](../aap-yamls/tower/ansibleproject-aap-demo.yaml)) has **no** field for Galaxy credentials or for toggling collection install; those live in Controller **settings** and **organization** configuration.

Use either the UI steps above or the helper script (Bearer token, same Secret pattern as other `aap-yamls` automation):

```bash
export CONTROLLER_HOST="https://<controller-route>"
export CONTROLLER_TOKEN="<oauth app token or PAT>"
./scripts/controller-wire-galaxy-for-default-org.sh
```

Then **sync the project** again in Controller.

---

## Reference

- Red Hat AAP 2.6 — [Configure collections from source management](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html/developing_automation_projects/projects-collections-support) (title may vary slightly by doc revision).
