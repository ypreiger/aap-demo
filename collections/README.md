# Ansible collections dependency file

This directory holds **`requirements.yml`** for **Galaxy-published** Ansible collections commonly used with:

| Area | Typical collections |
|------|---------------------|
| **OpenShift Virtualization / KubeVirt** | `kubernetes.core`, `community.kubevirt`, (optional) `community.okd` |
| **VMware vSphere** | `vmware.vmware_rest`, `community.vmware` |
| **F5** | `f5networks.f5_modules` |
| **Blue Coat / ProxySG** | *No mainstream Galaxy collection — see canonical doc.* |

Full checklist, pinning, Automation Hub substitutes, EE build notes: **[`../documentation/ANSIBLE_COLLECTIONS.md`](../documentation/ANSIBLE_COLLECTIONS.md)**.
