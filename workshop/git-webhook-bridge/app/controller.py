from __future__ import annotations

import httpx

from .settings import Settings


def _client(s: Settings) -> httpx.Client:
    return httpx.Client(
        base_url=s.controller_host.rstrip("/"),
        headers={"Authorization": f"Bearer {s.controller_token}"},
        verify=s.controller_verify_ssl,
        timeout=120.0,
    )


def controller_api_base(s: Settings) -> str:
    h = s.controller_host.rstrip("/")
    return h if h.endswith("/api") else f"{h}/api"


def find_project_id(s: Settings) -> int | None:
    """Return first project id whose name contains CONTROLLER_PROJECT_FILTER."""
    base = controller_api_base(s)
    filt = s.controller_project_name_contains
    with _client(s) as c:
        r = c.get(f"{base}/v2/projects/")
        r.raise_for_status()
        rows = r.json().get("results") or []
        for row in rows:
            if filt and filt not in (row.get("name") or ""):
                continue
            pk = row.get("id")
            if pk is not None:
                return int(pk)
        if rows:
            return int(rows[0]["id"])
    return None


def launch_project_update(s: Settings, project_id: int) -> dict:
    base = controller_api_base(s)
    with _client(s) as c:
        r = c.post(f"{base}/v2/projects/{project_id}/update/", json={"job_type": "run"})
        r.raise_for_status()
        return r.json()


def workflow_job_template_id(s: Settings, name: str) -> int | None:
    base = controller_api_base(s)
    with _client(s) as c:
        r = c.get(f"{base}/v2/workflow_job_templates/", params={"name": name})
        r.raise_for_status()
        res = (r.json().get("results") or [])
        if not res:
            return None
        return int(res[0]["id"])


def inventory_id_by_name(s: Settings, name: str) -> int | None:
    base = controller_api_base(s)
    with _client(s) as c:
        r = c.get(f"{base}/v2/inventories/", params={"name": name})
        r.raise_for_status()
        res = r.json().get("results") or []
        for row in res:
            if row.get("name") == name:
                return int(row["id"])
    return None


def launch_workflow(s: Settings, wjt_id: int, inv_id: int, extra_vars: dict) -> dict:
    base = controller_api_base(s)
    body = {"inventory": inv_id, "extra_vars": extra_vars}
    with _client(s) as c:
        r = c.post(f"{base}/v2/workflow_job_templates/{wjt_id}/launch/", json=body)
        r.raise_for_status()
        return r.json()
