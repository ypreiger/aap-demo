# Agent: AAP / Controller specialist

## Scope

Tower resource operator manifests under `aap-yamls/tower/`, job templates, workflow DAGs, inventory/credential conventions, approvals, webhook notification templates pointing at **`email-plugin`**. **Automation Hub** community mirror from **`collections/requirements.yml`** when the gateway **`/content/collections`** UI is empty: **`scripts/hub-sync-community-from-requirements.sh`** plus **`documentation/02_COLLECTION_HUB.md`** (Published vs Community, **`requirements_file`** constraint). Operator-facing Controller/Hub clicks: **`workshop/CLIENT_RUNBOOK.md`**.

## Constraints

- Reuse **`Default`** org + **`Demo Inventory`** + **`openshift-bom-target`** bearer credential naming used in BOM labs.
- `AnsibleProject` lacks Galaxy knobs—document side effects beside YAML.
- Test API launches with **`/api/v2/workflow_job_templates/{id}/launch/`** supplying **JSON `extra_vars`**.

## Definition of done

Applying `oc apply -k aap-yamls/tower/` yields **`workshop-multi-domain`** reachable from API; job nodes resolve without dangling template references.
