# Temporary ACS policy exceptions (AAP + RHACS)

Self-service, time-bounded **ACS policy exclusions** via Ansible Automation Platform in namespace **`aap`**. Policies are never disabled or deleted.

This directory is the demo root. AAP project **ACS-Exception-Demo** clones **this GitHub repo** and runs `acs-exceptions/playbooks/…`.

**Start here:** [docs/demo-runbook.md](docs/demo-runbook.md) — exact logins, URLs, form rules, and the 20-minute script.

| Doc | |
|---|---|
| [docs/use-cases.md](docs/use-cases.md) | UC-1…UC-12: deliverables, limitations, how to demonstrate |
| [docs/acs-exception-architecture.md](docs/acs-exception-architecture.md) | Flow + design choices |
| [docs/environment.md](docs/environment.md) | Live cluster discovery |
| [docs/verification-report.md](docs/verification-report.md) | Captured evidence |
| [docs/manual-steps.md](docs/manual-steps.md) | Fallbacks |

```bash
cd acs-exceptions
cp .env.example .env   # fill ACS_TOKEN, CONTROLLER_PASSWORD, persona passwords
./scripts/00-discovery.sh
ansible-playbook playbooks/setup-demo-fixtures.yml
python3 scripts/aap-config-apply.py
python3 scripts/preflight-demo.py
# then docs/demo-runbook.md
# optional proof: python3 scripts/e2e-happy-path.py
```

Personas are **AAP local users** (`alice` / `bob` / `carol` / `sre-approver`), not OpenShift SSO. Passwords live in `.env` only.

Portal **Create Task** lists job template **Temporary ACS Policy Exception** (not the workflow). SRE approves in AAP `#/workflow_approvals`.
