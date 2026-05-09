# Ansible collections — OpenShift virtualization, VMware, F5, Blue Coat

Canonical copy of this repository: **[https://github.com/ypreiger/aap-demo](https://github.com/ypreiger/aap-demo)**.

This repo’s **`collections/requirements.yml`** lists **Galaxy Ansible** collections for common infrastructure targets. It is oriented toward **Automation Controller**: either **sync Galaxy** into an Execution Environment image, or **`ansible-builder`** with the provided **`execution-environment/`** scaffolding.

If jobs fail with **missing collections** or project updates never install them, start with [**Controller: collections visibility and sync**](03_COLLECTION_CONTROLLER.md) (Galaxy credential on the **organization**, global **Enable Collection(s) Download**, then **sync** the Git project—or run **`scripts/controller-wire-galaxy-for-default-org.sh`**).

If **Automation Hub** itself lists **no** collections under the gateway **`/content/collections`** UI, mirror **`collections/requirements.yml`** into the **`community`** repository with **`scripts/hub-sync-community-from-requirements.sh`** — rationale and troubleshooting: [**Automation Hub collections (empty UI)**](02_COLLECTION_HUB.md).

---

## Quick install (development workstation)

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ansible-galaxy collection install -r collections/requirements.yml
```

Controller users usually **embed** dependencies in an **Execution Environment** (EE) container instead of resolving per job host.

---

## Execution & verification (CI + local)

**ansible-core version:** **`kubernetes.core`** 6.x expects **ansible-core 2.16+**. The Execution Environment definition and GitHub Actions workflow install **`ansible-core>=2.16,<2.19`** to match.

### Local (one command)

Requires **Python 3**, **PyYAML**, **ansible-core** (2.16+), and **ansible-builder** on `PATH`:

```bash
python3 -m pip install --user PyYAML "ansible-core>=2.16.0,<2.19.0" ansible-builder
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
./scripts/verify-collections-and-ee.sh
```

The script:

1. Validates **`collections/requirements.yml`** structure  
2. Runs **`ansible-galaxy collection install`** into a temp directory  
3. Runs **`ansible-builder introspect`** on that tree (Python / `bindep` footprint)  
4. Runs **`ansible-builder create`** for **`execution-environment/`** (writes a **Containerfile** context only — **no** `podman`/`docker` image build)  
5. Runs **`ansible-playbook --syntax-check`** on the demo + BOM playbooks with **`ANSIBLE_COLLECTIONS_PATHS`** pointing at the temp install  

### GitHub Actions

Workflow **`.github/workflows/verify-collections.yml`** runs the same script on every **push** / **pull_request** to **`main`**.

---

## OpenShift virtualization (KubeVirt / CNV)

| Galaxy collection | Purpose in this ecosystem |
|--------------------|---------------------------|
| **`kubernetes.core`** | Stable **Kubernetes** modules (`kubernetes.core.k8s`, `kubernetes.core.k8s_info`, …). **OpenShift Virtualization** VMs and related CRs (`VirtualMachine`, `DataVolume`, …) are Kubernetes resources—this is often enough with raw YAML or templated manifests. Already required by **BOM** playbooks here. |
| **`community.kubevirt`** | KubeVirt-oriented modules/helpers when you prefer not to craft every CR manually. Works against the **same kubeconfig/token** wired to **`kubernetes.core`**. |
| **`community.okd`** | Older **OpenShift-specific** workflows (routes, DeploymentConfig-era patterns). **Optional**—keep only if you use those APIs. |

**Red Hat Automation Hub:** organizations on AAP entitlement often consume **validated/collections** equivalents from **`console.redhat.com`**. Replace Galaxy `source` with your Automation Hub **`galaxy.yml` ansible.cfg `[galaxy]` `server`** when policy requires certified content only—module names largely align; verify product documentation for pinned versions.

**Docs:**  
- [Kubernetes collection](https://docs.ansible.com/ansible/latest/collections/kubernetes/core/index.html)  
- [community.kubevirt](https://docs.ansible.com/ansible/latest/collections/community/kubevirt/index.html)  

---

## VMware vSphere

| Galaxy collection | When to use it |
|------------------|----------------|
| **`vmware.vmware_rest`** | **REST‑based**, active development path for VMware automation; good default for greenfield playbooks. |
| **`community.vmware`** | **pyvmomi**-backed classics (`community.vmware.vmware_guest`, …)—still pervasive in enterprise. |

You may install **either or both**. Same target vCenter can justify **only `vmware_rest`** if you fully standardise on REST modules—many teams ship both during migration.

**Docs:**  
- [vmware.vmware_rest](https://docs.ansible.com/ansible/latest/collections/vmware/vmware_rest/index.html)  
- [community.vmware](https://docs.ansible.com/ansible/latest/collections/community/vmware/index.html)  

---

## F5 BIG-IP / BIG-IQ

| Galaxy collection | Notes |
|------------------|-------|
| **`f5networks.f5_modules`** | **Supported F5 Ansible collection**: AS3, declarative onboarding, BIG-IP LTM-centric modules (`bigip_virtual_server`, pools, certs, …). |
| **`f5networks.f5_bigip`** | Older Galaxy namespace; still published. Prefer **`f5_modules`** for new playbooks unless you depend on this artifact name. |

**Docs:**  
- Galaxy: [https://galaxy.ansible.com/ui/repo/published/f5networks/f5_modules/](https://galaxy.ansible.com/ui/repo/published/f5networks/f5_modules/)  
- Legacy: [https://galaxy.ansible.com/ui/repo/published/f5networks/f5_bigip/](https://galaxy.ansible.com/ui/repo/published/f5networks/f5_bigip/)  

---

## Event-Driven Ansible (EDA)

| Galaxy collection | Notes |
|------------------|-------|
| **`ansible.eda`** | Rulebooks, plugins, event filters, and related content for **Event-Driven Ansible**. |

**Docs:** [https://galaxy.ansible.com/ui/repo/published/ansible/eda/](https://galaxy.ansible.com/ui/repo/published/ansible/eda/)  

---

## Symantec Broadcom ProxySG (“Blue Coat”)

There is **no widely adopted, Ansible-maintained Galaxy collection** dedicated to **ProxySG / Blue Coat SGOS CLI** automation comparable to VMware or F5. Common approaches:

1. **`ansible.builtin.uri`** against **HTTPS management APIs** if your SGOS/feature mix exposes usable REST/HTML APIs (consult current Broadcom admin guides for your version).
2. **`ansible.builtin.expect`** over **SSH** for interactive enable-style shells (operators often treat this as brittle—wrap in hardened roles).
3. **Partner / vendor** automation packs delivered **outside Galaxy** — keep inventory in **`documentation/`** once you vendor them (license permitting).

Recommendation: prototype with **`ansible.builtin.uri`** plus small **credential + inventory** snippets in **`extras/`** when you settle on one API strategy; promote to a repo-local role if repetition grows. A disabled skeleton lives at **`extras/bluecoat-proxysg-uri.example.yml`** (`when: false`).

---

## Version pinning & supply chain

- **Demo / lab:** Installing without strict pins is simpler; Ansible pulls latest compatible minors from Galaxy at install time.
- **Production EE:** Pin **explicit collection versions** in `requirements.yml` (add `version: "x.y.z"` lines) once you certify a combo; rebuild EEs on deliberate upgrades only.
- **Private mirror:** Enterprises often mirror **`galaxy.ansible.com`** or use **Automation Hub** only — update `ansible.cfg` **`[galaxy] server`** or use **`ansible-galaxy`-compatible** tooling per platform docs.

---

## Execution Environment (recommended for Controller)

Minimal **`ansible-builder` v3** layout lives under **`execution-environment/`**:

```bash
cd execution-environment
ansible-builder build -t aap-demo-ee:devel -f execution-environment.yml
```

Point your Controller **Automation Execution Environment** registry image at the built artifact (or replicate the same `requirements.yml` in your central EE pipeline).

See **`execution-environment/README.md`** for variables and prerequisites.
