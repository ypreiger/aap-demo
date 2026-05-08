# Git webhook, EDA, and Controller rebuild semantics

Companion code: **`workshop/git-webhook-bridge/`**.

## Outbound envelope (EDA)

When **`EDA_WEBHOOK_URL`** is non-empty on the Bridge `ConfigMap`, every qualifying push posts JSON shaped like:

```json
{
  "ansible_eda_event": {
    "type": "scm.projects.changed",
    "delivery": {},
    "ref": "refs/heads/main",
    "repository": "org/repo",
    "changed_files": ["projects/proj1/domain/f5_service.yaml"],
    "domains_by_project": {"proj1": ["domain_f5"]}
  }
}
```

Wire this URL to the **EDA activation / webhook** your platform publishes (JWT headers differ per topology — use **`EDA_WEBHOOK_TOKEN`** when required).

## Controller refresh

Always queue an SCM **project update** for the Ansible project filtered by **`CONTROLLER_PROJECT_FILTER`** (“AAP Demo…” default) so Ansible Job copies match Git before playbook execution begins.

## Gated Automation

Webhook **never bypasses approvals**. It launches workflow **`workshop-projects-git-driven`**, whose **first node** waits on **`bom-approve-before-vms`** (same approval template as **`bom-project-deploy`** so one webhook + mail integration can cover both). To use a different gate, create another workflow approval template in Controller and update the **`WorkflowTemplate` CR**.
