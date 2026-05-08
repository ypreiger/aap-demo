# Event-Driven Ansible — workshop skeleton

Production rulebooks require a **Decision Environment** image, Controller credentials, and an event source (webhook plugin, Kafka, etc.). Files here are a **skeleton** for adaptation to your EDA version.

## Skeleton (validate against your EDA/ansible-rulebook version)

- Define a **`sources`** stanza pointing at **`ansible.eda.webhook`** (or your approved plugin).
- Map events to **`run_job_template`** with the **`workshop-mock-*`** jobs for integration demos.

Operational smoke script: **`workshop/scripts/verify-eda-route.sh`**.
