#!/usr/bin/env bash
# Install Galaxy collections listed in collections/requirements.yml, introspect them for EE
# dependencies, generate an Ansible Builder context (no Podman/Docker image build), and run
# ansible-playbook --syntax-check on repo playbooks.
#
# Prerequisites: Python 3 + PyYAML, ansible-core, ansible-builder (pip install ansible-core ansible-builder PyYAML).
# Usage (from repo root): ./scripts/verify-collections-and-ee.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

command -v python3 >/dev/null || {
  echo "python3 required" >&2
  exit 1
}
command -v ansible-galaxy >/dev/null || {
  echo "ansible-galaxy not found — install ansible-core (e.g. pip install ansible-core)" >&2
  exit 1
}
command -v ansible-builder >/dev/null || {
  echo "ansible-builder not found — pip install ansible-builder" >&2
  exit 1
}
command -v ansible-playbook >/dev/null || {
  echo "ansible-playbook not found — install ansible-core" >&2
  exit 1
}

python3 - <<'PY'
import re
import shutil
import subprocess
import sys

out = subprocess.run(
    [shutil.which("ansible-playbook"), "--version"],
    capture_output=True,
    text=True,
    check=True,
).stdout
m = re.search(r"ansible-playbook \[core ([0-9]+)\.([0-9]+)", out)
if not m:
    sys.exit("Could not parse ansible-playbook --version")
maj, mino = int(m.group(1)), int(m.group(2))
if (maj, mino) < (2, 16):
    sys.stderr.write(
        f"WARN: ansible-core {maj}.{mino} < 2.16 — kubernetes.core 6.x expects 2.16+ "
        f"(use Python 3.10+ and pip install 'ansible-core>=2.16,<2.19'). "
        f"GitHub Actions uses 3.11 and enforces this.\n"
    )
PY

echo "== [1/5] Validate collections/requirements.yml structure"
python3 - <<'PY'
import pathlib
import sys

try:
    import yaml  # type: ignore
except ImportError:
    print("Install PyYAML: pip install PyYAML", file=sys.stderr)
    sys.exit(1)

path = pathlib.Path("collections/requirements.yml")
data = yaml.safe_load(path.read_text())
collections = data.get("collections") or []
if not isinstance(collections, list) or not collections:
    sys.exit(f"{path}: expected non-empty collections list")
for idx, entry in enumerate(collections):
    if not isinstance(entry, dict) or "name" not in entry:
        sys.exit(f"{path}: collections[{idx}] missing name")
print(f"OK: {len(collections)} collections declared")
PY

GAL_TMP="$(mktemp -d)"
CTX_TMP="$(mktemp -d)"
cleanup() {
  rm -rf "${GAL_TMP}" "${CTX_TMP}"
}
trap cleanup EXIT

echo "== [2/5] ansible-galaxy collection install → ${GAL_TMP}"
ansible-galaxy collection install -r collections/requirements.yml -p "${GAL_TMP}" --force

echo "== [3/5] ansible-builder introspect (collection Python/bindep footprint)"
ansible-builder introspect "${GAL_TMP}" -v

echo "== [4/5] ansible-builder create (Containerfile context only, no image build)"
(
  cd execution-environment
  ansible-builder create -f execution-environment.yml -c "${CTX_TMP}" -v
)

echo "== [5/5] ansible-playbook --syntax-check (ANSIBLE_COLLECTIONS_PATHS=${GAL_TMP})"
export ANSIBLE_COLLECTIONS_PATHS="${GAL_TMP}:${ANSIBLE_COLLECTIONS_PATHS:-}"
for pb in \
  playbooks/01_validate_environment.yml \
  playbooks/02_publish_workflow_stats.yml \
  playbooks/03_finalize.yml \
  playbooks/project_foundation.yml \
  playbooks/project_vms.yml \
  playbooks/email_e2e_create_namespace.yml \
  playbooks/email_e2e_apply_netpol.yml; do
  echo "  syntax-check: ${pb}"
  ansible-playbook -i localhost, --connection=local --syntax-check "${pb}"
done

echo ""
echo "All verification steps succeeded."
