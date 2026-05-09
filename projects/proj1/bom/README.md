# BOM — `proj1` manifests

- **Namespace / ServiceAccount / NetworkPolicy** — static YAML in this directory (`namespace.yaml`, …).
- **VirtualMachines** — **not** declared as standalone files here anymore. They are rendered from **`aap-demo/playbooks/templates/bom-vm-fedora.yaml.j2`** when **`playbooks/project_vms.yml`** runs (sizes, disks, cluster instance types = **workflow survey / extra vars**).

See **`../../../documentation/09_VIRT_WORKFLOW_SURVEY.md`**.
