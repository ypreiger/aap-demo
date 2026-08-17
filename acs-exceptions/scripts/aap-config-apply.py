#!/usr/bin/env python3
"""Apply aap-config/*.yml to Automation Controller (idempotent REST). Secrets from env only."""
from __future__ import annotations

import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML required: python3 -m pip install pyyaml")

ROOT = Path(__file__).resolve().parents[1]
BASE = os.environ.get("AAP_API_BASE", "").rstrip("/")
HOST = os.environ.get("CONTROLLER_HOST") or os.environ.get("AAP_URL", "")
USER = os.environ.get("CONTROLLER_USERNAME", "admin")
PASS = os.environ.get("CONTROLLER_PASSWORD", "")
CTX = ssl._create_unverified_context()

if not BASE:
    BASE = HOST.rstrip("/") + "/api/controller/v2"


def api(method: str, path: str, body=None, ok=(200, 201, 202, 204)):
    url = path if path.startswith("http") else f"{BASE}{path}"
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, method=method)
    token = os.environ.get("AAP_TOKEN", "")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    else:
        import base64

        req.add_header("Authorization", "Basic " + base64.b64encode(f"{USER}:{PASS}".encode()).decode())
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, context=CTX) as resp:
            raw = resp.read()
            code = resp.status
            payload = json.loads(raw) if raw else {}
            if code not in ok:
                raise SystemExit(f"{method} {path} -> {code} {payload}")
            return payload
    except urllib.error.HTTPError as e:
        err = e.read().decode()
        if e.code in ok:
            return json.loads(err) if err else {}
        raise SystemExit(f"{method} {path} -> {e.code} {err[:800]}")


def get_by_name(collection: str, name: str, extra=""):
    field = "username" if collection == "users" else "name"
    q = urllib.parse.urlencode({field: name})
    data = api("GET", f"/{collection}/?{q}{extra}")
    results = data.get("results") or []
    return results[0] if results else None


def upsert(collection: str, name: str, body: dict, extra=""):
    existing = get_by_name(collection, name, extra)
    if existing:
        api("PATCH", f"/{collection}/{existing['id']}/", body, ok=(200, 201, 202))
        print(f"updated {collection} {name} id={existing['id']}")
        return existing["id"]
    created = api("POST", f"/{collection}/", body, ok=(201, 200))
    print(f"created {collection} {name} id={created.get('id')}")
    return created["id"]


def wait_project(pid: int, timeout=300):
    deadline = time.time() + timeout
    last = ""
    while time.time() < deadline:
        p = api("GET", f"/projects/{pid}/")
        status = p.get("status")
        if status != last:
            print(f"project {pid} status={status}")
            last = status
        if status in ("successful", "ok"):
            return
        if status in ("failed", "error"):
            raise SystemExit(f"project {pid} {status}")
        time.sleep(5)
    raise SystemExit(f"project {pid} still {last} after {timeout}s")


def mint_ocp_token() -> str:
    env_tok = os.environ.get("OCP_SA_TOKEN", "")
    try:
        import subprocess

        out = subprocess.check_output(
            ["oc", "create", "token", "aap-rbac-checker", "-n", "aap-demo", "--duration=720h"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
        if out:
            print("minted 720h OpenShift token for aap-rbac-checker")
            return out
    except Exception as exc:
        print(f"WARN oc create token failed ({exc}); falling back to OCP_SA_TOKEN")
    if not env_tok:
        raise SystemExit("OCP_SA_TOKEN is required (run setup-demo-fixtures.yml, oc login, then re-apply)")
    return env_tok


def approval_node_ready(wf_id: int) -> bool:
    nodes = api("GET", f"/workflow_job_templates/{wf_id}/workflow_nodes/?page_size=200")
    for n in nodes.get("results", []):
        if n.get("identifier") != "approval":
            continue
        ujt = (n.get("summary_fields") or {}).get("unified_job_template") or {}
        return ujt.get("unified_job_type") == "workflow_approval"
    return False


def load(name):
    return yaml.safe_load((ROOT / "aap-config" / name).read_text())


def main():
    ping = api("GET", "/ping/")
    print("controller", ping.get("version"))

    org = get_by_name("organizations", "Default")
    if not org:
        raise SystemExit("Default organization missing")
    org_id = org["id"]

    inv = get_by_name("inventories", "Demo Inventory")
    if not inv:
        inv_id = upsert(
            "inventories",
            "Demo Inventory",
            {"name": "Demo Inventory", "organization": org_id, "description": "localhost demos"},
        )
        api("POST", "/hosts/", {"name": "localhost", "inventory": inv_id, "variables": "ansible_connection: local\n"})
    else:
        inv_id = inv["id"]

    cred_types = load("credentials.yml")["controller_credential_types"]
    type_ids = {}
    for ct in cred_types:
        body = {
            "name": ct["name"],
            "description": ct.get("description", ""),
            "kind": ct.get("kind", "cloud"),
            "inputs": ct["inputs"],
            "injectors": {
                "env": {
                    k: v.replace("{{ '{{ ", "{{").replace(" }}' }}", " }}") if isinstance(v, str) else v
                    for k, v in (ct.get("injectors") or {}).get("env", {}).items()
                }
            },
        }
        # Injector templates must be literal {{ acs_url }} for Controller
        if ct["name"] == "ACS Central API":
            body["injectors"] = {"env": {"ACS_URL": "{{ acs_url }}", "ACS_TOKEN": "{{ acs_token }}", "ACS_VALIDATE_CERTS": "false"}}
        if ct["name"] == "AAP API":
            body["injectors"] = {
                "env": {
                    "AAP_URL": "{{ aap_url }}",
                    "AAP_TOKEN": "{{ aap_token }}",
                    "AAP_API_BASE": "{{ aap_url }}/api/controller/v2",
                    "CONTROLLER_HOST": "{{ aap_url }}",
                    "CONTROLLER_USERNAME": "admin",
                    "CONTROLLER_PASSWORD": "{{ aap_token }}",
                }
            }
        type_ids[ct["name"]] = upsert("credential_types", ct["name"], body)

    acs_type = type_ids["ACS Central API"]
    aap_type = type_ids["AAP API"]
    upsert(
        "credentials",
        "ACS Central",
        {
            "name": "ACS Central",
            "credential_type": acs_type,
            "organization": org_id,
            "inputs": {"acs_url": os.environ["ACS_URL"], "acs_token": os.environ["ACS_TOKEN"]},
        },
    )
    aap_tok = os.environ.get("AAP_TOKEN") or PASS
    upsert(
        "credentials",
        "AAP API token",
        {
            "name": "AAP API token",
            "credential_type": aap_type,
            "organization": org_id,
            "inputs": {"aap_url": os.environ.get("AAP_URL") or HOST, "aap_token": aap_tok},
        },
    )

    kube_types = api("GET", "/credential_types/?name=OpenShift%20or%20Kubernetes%20API%20Bearer%20Token")
    kube_type_id = None
    if kube_types.get("results"):
        kube_type_id = kube_types["results"][0]["id"]
    else:
        all_ct = api("GET", "/credential_types/?page_size=200")
        for t in all_ct.get("results", []):
            if "Kubernetes" in t.get("name", "") or "OpenShift" in t.get("name", ""):
                kube_type_id = t["id"]
                break
    if kube_type_id:
        host = os.environ.get("OCP_API") or os.environ.get("K8S_AUTH_HOST") or "https://kubernetes.default.svc"
        sa_token = mint_ocp_token()
        upsert(
                "credentials",
                "openshift-rbac-checker",
                {
                    "name": "openshift-rbac-checker",
                    "credential_type": kube_type_id,
                    "organization": org_id,
                    "inputs": {"host": host, "bearer_token": sa_token, "verify_ssl": False},
                },
            )
    else:
        raise SystemExit("OpenShift or Kubernetes API Bearer Token credential type not found")

    proj_cfg = load("projects.yml")["controller_projects"][0]
    proj_id = upsert(
        "projects",
        proj_cfg["name"],
        {
            "name": proj_cfg["name"],
            "organization": org_id,
            "scm_type": "git",
            "scm_url": proj_cfg["scm_url"],
            "scm_branch": proj_cfg.get("scm_branch", "main"),
            "scm_update_on_launch": True,
            "scm_update_cache_timeout": int(proj_cfg.get("scm_update_cache_timeout", 300)),
            "allow_override": False,
            "description": proj_cfg.get("description", ""),
        },
    )
    api("POST", f"/projects/{proj_id}/update/", {}, ok=(202, 200, 201, 204, 400))
    wait_project(proj_id)

    # Attach Galaxy? skip
    jt_ids = {}
    wf_survey = load("workflows.yml")["controller_workflows"][0].get("survey")

    def ensure_labels(kind, obj_id, labels):
        for label in labels or []:
            api(
                "POST",
                f"/{kind}/{obj_id}/labels/",
                {"name": label, "organization": org_id},
                ok=(200, 201, 204, 400),
            )

    for jt in load("job_templates.yml")["controller_templates"]:
        body = {
            "name": jt["name"],
            "job_type": "run",
            "inventory": inv_id,
            "project": proj_id,
            "playbook": jt["playbook"],
            "ask_variables_on_launch": jt.get("ask_variables_on_launch", False),
            "organization": org_id,
            "description": jt.get("description", ""),
            "survey_enabled": bool(jt.get("survey_enabled")),
        }
        jt_ids[jt["name"]] = upsert("job_templates", jt["name"], body)
        ensure_labels("job_templates", jt_ids[jt["name"]], jt.get("labels"))
        for cred_name in jt.get("credentials") or []:
            cred = get_by_name("credentials", cred_name)
            if cred:
                api(
                    "POST",
                    f"/job_templates/{jt_ids[jt['name']]}/credentials/",
                    {"id": cred["id"]},
                    ok=(204, 200, 201, 400),
                )
        if jt.get("survey_enabled") and wf_survey:
            api(
                "POST",
                f"/job_templates/{jt_ids[jt['name']]}/survey_spec/",
                wf_survey,
                ok=(200, 201),
            )

    wf_cfg = load("workflows.yml")["controller_workflows"][0]
    wf_id = upsert(
        "workflow_job_templates",
        wf_cfg["name"],
        {
            "name": wf_cfg["name"],
            "description": wf_cfg.get("description", ""),
            "organization": org_id,
            "inventory": inv_id,
            "survey_enabled": True,
            "ask_variables_on_launch": True,
        },
    )
    api("POST", f"/workflow_job_templates/{wf_id}/survey_spec/", wf_cfg["survey"], ok=(200, 201))
    ensure_labels("workflow_job_templates", wf_id, wf_cfg.get("labels") or ["self-service", "acs-exception"])

    if approval_node_ready(wf_id):
        print("workflow nodes already have Approval-Node-SRE — skip rebuild")
    else:
        existing_nodes = api("GET", f"/workflow_job_templates/{wf_id}/workflow_nodes/?page_size=200")
        for n in existing_nodes.get("results", []):
            api("DELETE", f"/workflow_job_template_nodes/{n['id']}/", ok=(204, 200, 202))

        node_ids = {}
        for node in wf_cfg["simplified_workflow_nodes"]:
            ident = node["identifier"]
            payload = {"identifier": ident, "workflow_job_template": wf_id}
            if node.get("unified_job_template"):
                payload["unified_job_template"] = jt_ids[node["unified_job_template"]]
            if node.get("extra_data"):
                payload["extra_data"] = node["extra_data"]
            created = api("POST", "/workflow_job_template_nodes/", payload, ok=(201, 200))
            node_ids[ident] = created["id"]
            if node.get("approval_node"):
                api(
                    "POST",
                    f"/workflow_job_template_nodes/{created['id']}/create_approval_template/",
                    {
                        "name": node["approval_node"]["name"],
                        "description": node["approval_node"].get("description", ""),
                        "timeout": int(node["approval_node"].get("timeout", 3600)),
                    },
                    ok=(201, 200),
                )
            print("node", ident, created["id"])

        for node in wf_cfg["simplified_workflow_nodes"]:
            src = node_ids[node["identifier"]]
            for rel, key in (("success_nodes", "success_nodes"), ("failure_nodes", "failure_nodes")):
                for dest_ident in node.get(key, []) or []:
                    dest = node_ids[dest_ident]
                    api("POST", f"/workflow_job_template_nodes/{src}/{rel}/", {"id": dest}, ok=(204, 200, 201, 204, 400))

    for sched in load("schedules.yml")["controller_schedules"]:
        jt = sched["unified_job_template"]
        upsert(
            "schedules",
            sched["name"],
            {
                "name": sched["name"],
                "unified_job_template": jt_ids[jt],
                "rrule": sched["rrule"],
                "enabled": sched.get("enabled", True),
            },
        )

    rbac = load("rbac.yml")
    for u in rbac["controller_users"]:
        existing = get_by_name("users", u["username"])
        body = {"username": u["username"], "is_superuser": False}
        env_key = {
            "alice": "AAP_USER_ALICE_PASSWORD",
            "bob": "AAP_USER_BOB_PASSWORD",
            "carol": "AAP_USER_CAROL_PASSWORD",
            "sre-approver": "AAP_USER_SRE_PASSWORD",
        }.get(u["username"])
        pw = os.environ.get(env_key or "", "") or os.environ.get("AAP_DEMO_USER_PASSWORD", "ChangeMe123!")
        body["password"] = pw
        if not existing:
            created = api("POST", "/users/", body, ok=(201, 200, 400))
            uid = created.get("id") if isinstance(created, dict) else None
            print("user", u["username"])
        else:
            uid = existing["id"]
            api("PATCH", f"/users/{uid}/", {"password": pw}, ok=(200, 201, 204))
            print("user exists", u["username"], "(password synced)")
        if uid:
            api("POST", f"/organizations/{org_id}/users/", {"id": uid}, ok=(204, 200, 201, 400))
        gw = (HOST or "").rstrip("/") + "/api/gateway/v1"
        if gw.startswith("http") and uid:
            api("PATCH", f"{gw}/users/{uid}/", {"password": pw}, ok=(200, 201, 204, 404))

    team_id = upsert("teams", "SRE-Approvers", {"name": "SRE-Approvers", "organization": org_id})
    sre = get_by_name("users", "sre-approver")
    if sre:
        api("POST", f"/teams/{team_id}/users/", {"id": sre["id"]}, ok=(204, 200, 201, 400))

    wf = get_by_name("workflow_job_templates", wf_cfg["name"])
    # execute role for users
    roles = api("GET", f"/workflow_job_templates/{wf['id']}/object_roles/")
    role_map = {r["name"]: r["id"] for r in roles.get("results", [])}
    for username, role_name in (("alice", "Execute"), ("bob", "Execute"), ("carol", "Execute")):
        user = get_by_name("users", username)
        rid = role_map.get(role_name) or role_map.get(role_name.lower())
        if user and rid:
            api("POST", f"/roles/{rid}/users/", {"id": user["id"]}, ok=(204, 200, 201, 400))
    portal_jt_id = jt_ids.get("Temporary ACS Policy Exception")
    if portal_jt_id:
        jt_roles = api("GET", f"/job_templates/{portal_jt_id}/object_roles/")
        jt_role_map = {r["name"]: r["id"] for r in jt_roles.get("results", [])}
        exec_id = jt_role_map.get("Execute") or jt_role_map.get("execute")
        for username in ("alice", "bob", "carol"):
            user = get_by_name("users", username)
            if user and exec_id:
                api("POST", f"/roles/{exec_id}/users/", {"id": user["id"]}, ok=(204, 200, 201, 400))
    approve_id = role_map.get("Approval") or role_map.get("Approve")
    if approve_id:
        api("POST", f"/roles/{approve_id}/teams/", {"id": team_id}, ok=(204, 200, 201, 400))

    missing = []
    for jt in load("job_templates.yml")["controller_templates"]:
        want = set(jt.get("credentials") or [])
        if not want:
            continue
        have = {
            c["name"]
            for c in api("GET", f"/job_templates/{jt_ids[jt['name']]}/credentials/").get("results", [])
        }
        for cred_name in want:
            if cred_name not in have:
                missing.append(f"{jt['name']} missing credential {cred_name}")
    if not approval_node_ready(wf_id):
        missing.append("workflow approval node has no workflow_approval template")
    if missing:
        raise SystemExit("apply verification failed:\n  " + "\n  ".join(missing))

    print("aap-config-apply complete")
    print("job_templates", sorted(jt_ids))
    print("workflow", wf_id)
    print("approvals", f"{(os.environ.get('AAP_URL') or HOST).rstrip('/')}/#/workflow_approvals")


if __name__ == "__main__":
    main()
