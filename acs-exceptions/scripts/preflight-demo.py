#!/usr/bin/env python3
"""Fail closed if the ACS exception demo is not ready to present."""
from __future__ import annotations

import base64
import json
import os
import ssl
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENV = ROOT / ".env"
if ENV.exists():
    for line in ENV.read_text().splitlines():
        if line.strip() and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            os.environ.setdefault(k, v)

CTX = ssl._create_unverified_context()
HOST = os.environ["AAP_URL"].rstrip("/")
BASE = os.environ.get("AAP_API_BASE", HOST + "/api/controller/v2").rstrip("/")
USER = os.environ.get("CONTROLLER_USERNAME", "admin")
PASS = os.environ["CONTROLLER_PASSWORD"]
ACS = os.environ["ACS_URL"].rstrip("/")
ACS_TOKEN = os.environ["ACS_TOKEN"]
errors: list[str] = []
ok: list[str] = []


def aap(path: str, user=None, password=None):
    r = urllib.request.Request(BASE + path)
    u, p = user or USER, password or PASS
    r.add_header("Authorization", "Basic " + base64.b64encode(f"{u}:{p}".encode()).decode())
    try:
        with urllib.request.urlopen(r, context=CTX) as resp:
            return resp.status, json.load(resp)
    except urllib.error.HTTPError as e:
        return e.code, {}


def acs(path: str):
    r = urllib.request.Request(ACS + path)
    r.add_header("Authorization", f"Bearer {ACS_TOKEN}")
    with urllib.request.urlopen(r, context=CTX) as resp:
        return json.load(resp)


def check(cond: bool, good: str, bad: str):
    if cond:
        ok.append(good)
    else:
        errors.append(bad)


st, ping = aap("/ping/")
check(st == 200, f"AAP ping {ping.get('version')}", f"AAP ping HTTP {st}")

meta = acs("/v1/metadata")
check(True, f"ACS {meta.get('version', {}).get('version', meta)}", "ACS metadata failed")

st, _ = aap("/me/", user="alice", password=os.environ.get("AAP_USER_ALICE_PASSWORD", ""))
check(st == 200, "alice login", f"alice login HTTP {st}")
st, _ = aap("/me/", user="sre-approver", password=os.environ.get("AAP_USER_SRE_PASSWORD", ""))
check(st == 200, "sre-approver login", f"sre-approver login HTTP {st}")

st, wfs = aap("/workflow_job_templates/?name=WF-Temporary-ACS-Policy-Exception")
wf = (wfs.get("results") or [None])[0]
check(wf is not None, f"workflow id {wf['id'] if wf else '?'}", "workflow missing")
if wf:
    st, nodes = aap(f"/workflow_job_templates/{wf['id']}/workflow_nodes/?page_size=50")
    approval = next((n for n in nodes.get("results", []) if n.get("identifier") == "approval"), None)
    ujt = ((approval or {}).get("summary_fields") or {}).get("unified_job_template") or {}
    check(
        ujt.get("unified_job_type") == "workflow_approval",
        "Approval-Node-SRE is a real approval template",
        f"approval node is not an approval template ({ujt})",
    )
    st, spec = aap(f"/workflow_job_templates/{wf['id']}/survey_spec/")
    ns = next((s for s in spec.get("spec", []) if s.get("variable") == "namespace"), {})
    choices = ns.get("choices") or []
    if isinstance(choices, str):
        choices = [c for c in choices.split("\n") if c]
    check(
        set(choices) == {"demo-app", "demo-restricted"},
        "survey namespaces are demo-app / demo-restricted",
        f"survey namespaces are {choices}",
    )

expected = {
    "Temporary ACS Policy Exception": ["AAP API token"],
    "JT-01-Validate-Namespace-RBAC": ["openshift-rbac-checker"],
    "JT-02-Apply-ACS-Exception": ["ACS Central"],
    "JT-03-Rollback-ACS-Exception": ["ACS Central", "AAP API token"],
    "JT-04-Create-Rollback-Schedule": ["AAP API token"],
    "JT-06-Reconcile-Expired-Exceptions": ["ACS Central"],
}
st, jts = aap("/job_templates/?page_size=50")
by_name = {j["name"]: j["id"] for j in jts.get("results", [])}
for name, want in expected.items():
    jtid = by_name.get(name)
    if not jtid:
        errors.append(f"job template {name} missing")
        continue
    st, creds = aap(f"/job_templates/{jtid}/credentials/")
    have = {c["name"] for c in creds.get("results", [])}
    for c in want:
        check(c in have, f"{name} has {c}", f"{name} missing credential {c}")

exec_pol = acs("/v1/policies/8ab0f199-4904-4808-9461-3501da1d1b77")
check(
    "FAIL_KUBE_REQUEST_ENFORCEMENT" in (exec_pol.get("enforcementActions") or []),
    "Exec-into-Pod runtime enforcement is on",
    f"Exec-into-Pod enforcement={exec_pol.get('enforcementActions')}",
)
aapex = [e.get("name") for e in exec_pol.get("exclusions") or [] if str(e.get("name", "")).startswith("AAPEX-")]
if aapex:
    errors.append(f"stale AAPEX exclusions still on exec policy: {aapex} (run demo-reset.yml)")
else:
    ok.append("no stale AAPEX exclusions on exec policy")

try:
    out = subprocess.run(
        ["oc", "exec", "-n", "demo-app", "deploy/nginx", "--", "date"],
        capture_output=True,
        text=True,
        timeout=30,
    )
    blocked = out.returncode != 0 and "k8sevents.stackrox.io" in (out.stderr + out.stdout)
    check(
        blocked,
        "oc exec in demo-app is blocked by ACS",
        f"oc exec not blocked: rc={out.returncode} {out.stderr[-300:]}",
    )
except Exception as exc:
    errors.append(f"oc exec check failed: {exc}")

try:
    subprocess.check_call(
        ["oc", "get", "deploy", "nginx", "-n", "demo-restricted"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    ok.append("demo-restricted/nginx exists for blast-radius")
except Exception:
    errors.append("demo-restricted/nginx missing — run setup-demo-fixtures.yml")

print("OK:")
for line in ok:
    print("  -", line)
if errors:
    print("FAIL:")
    for line in errors:
        print("  -", line)
    sys.exit(1)
print("demo preflight passed")
print("portal: https://aap-portal-rhaap-portal-aap.apps.ocp.7hrxw.sandbox880.opentlc.com/")
print(f"approvals: {HOST}/#/workflow_approvals")
print("personas are AAP local users (alice / sre-approver); passwords are in acs-exceptions/.env")
print("justification must be at least 10 characters")
