# Automation Execution Environment (optional)

Defines a container image intended for **Ansible Automation Platform** Job Templates built with **`ansible-builder`**.

Prerequisites on your build machine:

- **Podman** or **Docker**
- **`ansible-builder`** matching your AAP-supported major version (`pip install ansible-builder`)
- **`ansible-core` 2.16+** (`kubernetes.core` in this repo’s Galaxy file is tested with 2.16–2.18 — see **`execution-environment.yml`**)

From this directory:

```bash
ansible-builder build -t localhost/aap-demo-ee:devel -f execution-environment.yml
```

The image inherits Galaxy dependencies from **`../collections/requirements.yml`**, which includes **`f5networks.f5_modules`** (BIG-IP / AS3 modules). Rebuild and redeploy the image after changing that file.

Build notes (local Podman/Docker):

- Base **`registry.access.redhat.com/ubi9/python-311:latest`** plus **`python_interpreter.python_path: /usr/bin/python3.11`** so **`ansible-core>=2.16`** installs correctly (`/usr/bin/python3` on that image is still 3.9).
- **`openshift-clients`** is excluded from merged bindep because it is not in default UBI repos; **`kubernetes.core`** uses the Python client bundled via pip in the EE.
- **`systemd-python`** (from **`ansible.eda`**) is excluded so **`ansible-builder`** can assemble on stock UBI without **`libsystemd`** headers; add **`systemd-devel`** / reinstate the pip package if you need journal-related EDA plugins inside the EE.

**Controller:** Push the tagged image to a registry your Controller can pull, register it under **Automation → Execution environments**, then attach it to your Job Templates.

For pinning and certified-content strategy, see **`../documentation/04_COLLECTION_REFERENCE.md`** (and **`../documentation/02_COLLECTION_HUB.md`** for Automation Hub).
