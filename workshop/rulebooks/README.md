# Event-Driven Ansible — workshop skeleton

Real activations need a Decision Environment image, Controller credentials, and a chosen event source (webhook plugin, Kafka, etc.). Treat this folder as **presenter notes**.

## Skeleton (validate against your EDA/ansible-rulebook version)

- Define a **`sources`** stanza pointing at **`ansible.eda.webhook`** (or your approved plugin).
- Map events to **`run_job_template`** with the **`workshop-mock-*`** jobs for integration demos.

Operational smoke script: **`workshop/scripts/verify-eda-route.sh`**.
