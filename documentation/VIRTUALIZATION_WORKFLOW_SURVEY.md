# OpenShift Virtualization — BOM workflow VMs (survey‑driven)

When you launch **`bom-project-deploy`**, Controller prompts for **CPU / memory strategy**, **root disk backing**, optional **extra virtio disk**, and related fields. **`playbooks/project_vms.yml`** renders **`VirtualMachine`** objects from **`playbooks/templates/bom-vm-fedora.yaml.j2`**.

Canonical repo copy: **`https://github.com/ypreiger/aap-demo`**.

---

## Two sizing modes (`vm_sizing_mode`)

### `cluster_instancetype` (recommended on OpenShift with Virtualization)

Uses operator‑supplied **`VirtualMachineClusterInstancetype`** and optional **`VirtualMachineClusterPreference`** (what the GUI often calls sizing / preferences).

Before picking names, inspect the cluster:

```bash
oc get virtualmachineclusterinstancetype
oc get virtualmachineclusterpreference
```

Survey defaults (**`vm_cluster_instancetype`**, **`vm_cluster_preference`**) should match CR **names**. On many clusters **`u1.small` / `u1.medium`** and **`fedora`** work; naming can differ (`n1.medium`, etc.). If an apply fails Admission Webhook rejects unknown instance type names—switch **`vm_sizing_mode`** to **`manual`** or adjust names.

Leave **`vm_cluster_preference`** empty on the JT / extra vars to omit **`spec.preference`** (some combinations with custom disk layouts are picky).

### `manual`

Uses **`spec.template.spec.domain.cpu`** and **`spec.template.spec.domain.resources.requests.memory`** from survey **`vm_cpu_cores`** and **`vm_memory_gi`**. Works wherever KubeVirt runs, even without cluster instance type CRs.

---

## Root disk (`vm_root_disk_mode`)

### `container` (default workshops)

Imports **`spec.template.spec.volumes[].containerDisk`** from **`vm_container_root_image`** (default **`quay.io/kubevirt/fedora-container-disk-images:41`**).

### `datasource`

Creates **`spec.dataVolumeTemplates[]`** cloning the **`DataSource`** **`fedora`** in **`openshift-virtualization-os-images`** (`vm_datasource_name` / `vm_datasource_namespace` overridable). Requires working **CDI** + **storage** in the namespace.

Survey **`vm_root_volume_size_gi`** sets PVC size.**`vm_storage_class`** empty ⇒ omit **`storageClassName`** (cluster default).

---

## Extra disk (`vm_extra_disk_gi`)

If **> 0**, adds **`emptyDisk`** + virtio disk (scratch / data volumes without a separate PVC). Good for demos; production often wants a **`DataVolumeTemplate`** + **`StorageClass`** instead (extend **`bom-vm-fedora.yaml.j2`** if you standardise on PVCs).

---

## Which VMs exist?

Logical list **`bom_vms`** (names + hostnames) lives in **`playbooks/vars/bom_vms_defaults.yml`**. To add a third Fedora VM, extend that list in Git—not the workflow survey—then re‑sync Project.

---

## Controller wiring

Survey lives on **`bom-project-deploy`** (`aap-yamls/tower/workflowtemplate-project-deploy.yaml`). Job template **`bom-project-vms`** has matching **`extra_vars`** defaults (`aap-yamls/tower/jobtemplate-project-vms.yaml`). Launch the **workflow** so survey fires once before foundation; children inherit **`extra_vars`** for **`project_vms`** (and **`project_name`** stays aligned).

**Standalone** **`bom-project-vms`**: **`ask_variables_on_launch: true`** so you can provide the same keys manually.

---

## Passwords / security

Survey includes **`vm_cloud_user_password`** (cloud‑init **`fedora`** user). Prefer **credentials / Vault / secrets automation** outside Git for real workloads.
