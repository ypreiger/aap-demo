# `projects/` in Git ↔ namespaces on the cluster

This note ties together **Automation Controller “Projects”** (SCM), the **`projects/`** directory in this repository, and what is (and is not) synchronized today.

---

## Two meanings of “project”

| Term | Meaning |
|------|---------|
| **Automation Controller → Projects** | One **SCM project**: a single Git URL (e.g. **`aap-demo`**) that the controller **syncs** into its job sandbox. That checkout contains the **whole** repo, including **`projects/proj1/`**, **`projects/proj2/`**, … |
| **`aap-demo/projects/<slug>/`** | **Logical BOM/domain layout** inside the same Git repo: **`bom/`** (namespace, SA, netpol) and **`domain/`** (F5, firewall, …). Surveys and playbooks use **`project_name`** = that **`<slug>`**. |

So you **link** them by convention: **one Controller SCM project** holds **many** logical projects as subdirectories. You do **not** need one Controller project per `proj1`/`proj2` unless you split repositories.

---

## What is implemented today (Git → cluster)

1. **Push** to GitHub under **`projects/**`** (BOM or domain YAML).
2. **`workshop/git-webhook-bridge`** receives the webhook, classifies paths ([`app/classify.py`](../workshop/git-webhook-bridge/app/classify.py)), optionally notifies EDA, then triggers a Controller **SCM project update** for the configured project (default name filter matches **`AAP Demo (GitHub)`**).
3. After sync, the gated workflow **`workshop-projects-git-driven`** can run the dispatcher so jobs use **fresh** files from Git.

Details: [EDA_GIT_WEBHOOK.md](EDA_GIT_WEBHOOK.md), bridge [README](../workshop/git-webhook-bridge/README.md).

**BOM playbooks** ([`playbooks/project_foundation.yml`](../playbooks/project_foundation.yml), [`project_vms.yml`](../playbooks/project_vms.yml)) **read manifests from disk** under **`projects/{{ project_name }}/bom/`** on the controller checkout. The namespace name in **`namespace.yaml`** must **match** **`project_name`**.

So the **authoritative** description of a namespace (name, labels, SA, netpol) is **Git**; the cluster is updated to match after sync + workflow.

---

## What is not implemented (cluster → Git)

If an operator **creates or changes** namespaces or parameters **only** in OpenShift or **only** via Controller surveys **without** a matching change in Git, those changes are **not** written back to GitHub by this repository. There is no built-in “reconcile export” job.

That matters if you want:

- A **new** `project_name` (e.g. **`proj3`**) created **only** from a workflow survey **without** adding **`projects/proj3/bom/`** in Git first — **`project_foundation.yml` will fail** because it **`lookup`s `namespace.yaml`** from that path.

---

## Recommended patterns for “bi-directional” behaviour

### Pattern A — Git-first (matches current playbooks; true config drift control)

1. Add or edit **`projects/<slug>/bom/*.yaml`** (and **`domain/`** as needed) in Git.
2. Merge to the branch the Controller project tracks.
3. Let the **webhook + SCM sync** (and **`workshop-projects-git-driven`**) apply the change, or run **`bom-project-deploy`** / **`workshop-multi-domain`** manually after **Projects → Sync**.

**Cluster state** follows **Git**; reviews happen on PRs.

### Pattern B — Scaffold in Git, then automate (still Git-first, nicer UX)

For a “new customer” slug:

1. **Template** a new folder (copy `proj1` → `proj3`, adjust `namespace.yaml` / SA / netpol names).
2. Open a **PR** (human or CI).
3. After merge, **webhook** or manual sync runs the workflow.

Optional future enhancement: a **scaffolding** playbook or **outside** tool (Backstage, cookiecutter, `ansible-playbook` in CI) that only **writes files into Git** (branch + PR), never creates the namespace “by magic” without Git.

### Pattern C — Cluster → Git (requires new automation)

To reflect **runtime** choices back to GitHub you would add something **outside** the current tree, for example:

- A **follow-on job template** with a **Source Control credential** that can **push** (or open a PR via GitHub/GitLab API), committing rendered YAML under **`projects/<slug>/`**; or  
- A **small service** (like the webhook bridge) that listens to **Kubernetes** events or **Controller job completion** and opens PRs.

That needs **secrets**, **branch policy**, and **idempotency** (avoid loops: Git push → webhook → job → Git push). This repo does **not** ship that path yet; design it before enabling any auto-push to `main`.

---

## Summary

| Direction | Status |
|-----------|--------|
| **Git `projects/` → SCM sync → workflows → cluster** | Supported ([EDA_GIT_WEBHOOK.md](EDA_GIT_WEBHOOK.md), bridge, Tower CRs). |
| **Cluster / survey-only → Git** | **Not** implemented; use Pattern A/B for new slugs, or plan Pattern C explicitly. |
| **Linking** | **One** Controller **Project** (whole repo) + **`project_name`** selects **`projects/<slug>/`**. |

For domain file semantics, see [DOMAIN_INPUT.md](DOMAIN_INPUT.md).
