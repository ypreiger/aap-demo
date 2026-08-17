#!/usr/bin/env python3
"""Happy-path E2E: launch as alice, approve as sre-approver, prove oc exec unblocks."""
from __future__ import annotations

import base64
import json
import os
import ssl
import subprocess
import sys
import time
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
ADMIN = os.environ.get("CONTROLLER_USERNAME", "admin")
ADMIN_PW = os.environ["CONTROLLER_PASSWORD"]
ALICE_PW = os.environ["AAP_USER_ALICE_PASSWORD"]
SRE_PW = os.environ["AAP_USER_SRE_PASSWORD"]
ACS = os.environ["ACS_URL"].rstrip("/")
ACS_TOKEN = os.environ["ACS_TOKEN"]
EXEC_POLICY = "8ab0f199-4904-4808-9461-3501da1d1b77"


def api(method, path, body=None, user=None, password=None):
    data = None if body is None else json.dumps(body).encode()
    r = urllib.request.Request(BASE + path, data=data, method=method)
    u, p = user or ADMIN, password or ADMIN_PW
    r.add_header("Authorization", "Basic " + base64.b64encode(f"{u}:{p}".encode()).decode())
    if body is not None:
        r.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(r, context=CTX) as resp:
            raw = resp.read()
            return resp.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            payload = json.loads(raw) if raw else {}
        except Exception:
            payload = {"text": raw.decode()[:800]}
        return e.code, payload


def get(path, **kw):
    return api("GET", path, **kw)[1]


def acs_aapex():
    r = urllib.request.Request(f"{ACS}/v1/policies/{EXEC_POLICY}")
    r.add_header("Authorization", f"Bearer {ACS_TOKEN}")
    with urllib.request.urlopen(r, context=CTX) as resp:
        pol = json.load(resp)
    return [e.get("name") for e in pol.get("exclusions") or [] if str(e.get("name", "")).startswith("AAPEX-")]


def oc_exec(ns: str) -> tuple[int, str]:
    out = subprocess.run(
        ["oc", "exec", "-n", ns, "deploy/nginx", "--", "date"],
        capture_output=True,
        text=True,
        timeout=30,
    )
    return out.returncode, (out.stdout + out.stderr)


print("launch workflow as alice")
st, payload = api(
    "POST",
    "/workflow_job_templates/16/launch/",
    {
        "extra_vars": {
            "namespace": "demo-app",
            "policy_name": "Kubernetes Actions: Exec into Pod",
            "duration_minutes": "5",
            "justification": "e2e happy path for terminal access exception",
            "ticket_id": "INC-E2E",
            "requesting_user": "alice",
        }
    },
    user="alice",
    password=ALICE_PW,
)
if st not in (200, 201):
    sys.exit(f"launch failed {st} {payload}")
wjid = payload["id"]
print("workflow job", wjid)

deadline = time.time() + 180
appr_id = None
while time.time() < deadline:
    aps = get("/workflow_approvals/?status=pending")
    for a in aps.get("results", []):
        wf = ((a.get("summary_fields") or {}).get("workflow_job") or {})
        if wf.get("id") == wjid:
            appr_id = a["id"]
            break
    if appr_id:
        break
    wf = get(f"/workflow_jobs/{wjid}/")
    if wf.get("status") in ("successful", "failed", "error", "canceled"):
        sys.exit(f"workflow {wjid} finished {wf['status']} before approval")
    time.sleep(4)
if not appr_id:
    sys.exit("no pending approval")
print("pending approval", appr_id)

st, _ = api("POST", f"/workflow_approvals/{appr_id}/approve/", {}, user="sre-approver", password=SRE_PW)
print("approve", st)
if st not in (200, 201, 204):
    sys.exit("approve failed")

deadline = time.time() + 180
while time.time() < deadline:
    nodes = get(f"/workflow_jobs/{wjid}/workflow_nodes/")
    by_id = {n.get("identifier"): n for n in nodes.get("results", [])}
    jt02 = ((by_id.get("jt02") or {}).get("summary_fields") or {}).get("job") or {}
    jt04 = ((by_id.get("jt04") or {}).get("summary_fields") or {}).get("job") or {}
    print("jt02", jt02.get("status"), "jt04", jt04.get("status"))
    if jt02.get("status") == "failed":
        sys.exit("JT-02 failed")
    if jt02.get("status") == "successful" and jt04.get("status") in ("successful", "failed", None):
        if jt04.get("status") == "failed":
            sys.exit("JT-04 failed")
        if jt04.get("status") == "successful":
            break
    time.sleep(5)
else:
    sys.exit("timed out waiting for JT-02/JT-04")

names = acs_aapex()
print("ACS AAPEX exclusions", names)
if not names:
    sys.exit("no AAPEX exclusion after apply")

rc, text = oc_exec("demo-app")
print("oc exec demo-app rc", rc, text[-200:])
if rc != 0:
    sys.exit("expected oc exec in demo-app to succeed after exception")

rc2, text2 = oc_exec("demo-restricted")
print("oc exec demo-restricted rc", rc2, text2[-200:])
if rc2 == 0 or "k8sevents.stackrox.io" not in text2:
    sys.exit("expected oc exec in demo-restricted to stay blocked")

sched = get("/schedules/?search=AAPEX-rollback-")
rollback = [s["name"] for s in sched.get("results", []) if s["name"].startswith("AAPEX-rollback-")]
print("rollback schedules", rollback)
if not rollback:
    sys.exit("no AAPEX-rollback schedule")

print("E2E PASS")
print("workflow", wjid, "approval", appr_id, "exclusion", names)
print("wait ~5 minutes for scheduled rollback, or run: ansible-playbook playbooks/demo-reset.yml")
