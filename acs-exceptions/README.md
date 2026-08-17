# Temporary ACS policy exceptions (AAP + RHACS)

Self-service, time-bounded **ACS policy exclusions** via Ansible Automation Platform in namespace **`aap`**. Policies are never disabled or deleted.

This directory is the demo root (playbooks, `aap-config/`, roles). The AAP project **ACS-Exception-Demo** clones **this GitHub repo** (`ypreiger/aap-demo`) and runs playbooks at `acs-exceptions/playbooks/…`.

| Doc | |
|---|---|
| [docs/demo-runbook.md](docs/demo-runbook.md) | 20-minute customer script |
| [docs/acs-exception-architecture.md](docs/acs-exception-architecture.md) | Flow + design choices |
| [docs/environment.md](docs/environment.md) | Live cluster discovery |
| [docs/verification-report.md](docs/verification-report.md) | Captured evidence |
| [docs/manual-steps.md](docs/manual-steps.md) | Fallbacks |

```bash
cd acs-exceptions
cp .env.example .env   # fill ACS_TOKEN / CONTROLLER_PASSWORD locally
./scripts/00-discovery.sh
ansible-playbook playbooks/setup-demo-fixtures.yml
python3 scripts/aap-config-apply.py
# then docs/demo-runbook.md
```

AAP already runs in namespace `aap` on this cluster. Do not install AAP into the ISO compliance repo.
