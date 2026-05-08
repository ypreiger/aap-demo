# Ansible collections dependency file

This directory holds **`requirements.yml`** for **Galaxy-published** Ansible collections commonly used with:

| Area | Typical collections |
|------|---------------------|
| **OpenShift Virtualization / KubeVirt** | `kubernetes.core`, `community.kubevirt`, (optional) `community.okd` |
| **VMware vSphere** | `vmware.vmware_rest`, `community.vmware` |
| **F5** | `f5networks.f5_modules` |
| **Blue Coat / ProxySG** | *No mainstream Galaxy collection — see canonical doc.* |

Full checklist, pinning, Automation Hub substitutes, EE build notes: **[`../documentation/ANSIBLE_COLLECTIONS.md`](../documentation/ANSIBLE_COLLECTIONS.md)**.

If **Automation Hub** shows an **empty** **`/content/collections`** UI until Community is synced from Galaxy, mirror this file into Hub with **`../scripts/hub-sync-community-from-requirements.sh`** (see **[`../documentation/HUB_COLLECTIONS.md`](../documentation/HUB_COLLECTIONS.md)**).

Automated verification (**Galaxy install**, **ansible-builder introspect/create**, **`--syntax-check`**): run **`../scripts/verify-collections-and-ee.sh`** from the repo root (see doc — also **GitHub Actions**).
