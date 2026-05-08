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

The image inherits Galaxy dependencies from **`../collections/requirements.yml`**.

**Controller:** Push the tagged image to a registry your Controller can pull, register it under **Automation → Execution environments**, then attach it to your Job Templates.

For pinning and certified-content strategy, see **`../documentation/COLLECTION_REFERENCE.md`**.
