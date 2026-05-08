"""Automation Controller API helpers."""

from __future__ import annotations

import httpx

from .settings import Settings


def _client(s: Settings) -> httpx.Client:
    return httpx.Client(
        base_url=s.controller_host.rstrip("/"),
        headers={"Authorization": f"Bearer {s.controller_token}"},
        verify=s.controller_verify_ssl,
        timeout=60.0,
    )


def _coerce_int(v: object) -> int | None:
    if v is None:
        return None
    if isinstance(v, int):
        return v
    if isinstance(v, str) and v.isdigit():
        return int(v)
    return None


def _approval_status_open(status: str | None) -> bool:
    """True if this unified job is still waiting on a human (not finished)."""
    st = (status or "").lower()
    return st not in ("successful", "failed", "canceled", "error")


def _node_is_workflow_approval(node: dict) -> bool:
    sj = (node.get("summary_fields") or {}).get("job") or {}
    ujt = (node.get("summary_fields") or {}).get("unified_job_template") or {}
    if sj.get("type") == "workflow_approval":
        return True
    return ujt.get("unified_job_type") == "workflow_approval"


def workflow_job_id_from_approval(appr: dict) -> int | None:
    """AAP 4.7+ uses workflow_approvals (summary_fields.workflow_job); older AWX used top-level workflow_job."""
    w = _coerce_int(appr.get("workflow_job"))
    if w is not None:
        return w
    return _coerce_int((appr.get("summary_fields") or {}).get("workflow_job", {}).get("id"))


def first_pending_workflow_approval_id(s: Settings, workflow_job_id: int) -> int | None:
    """Return first open workflow approval id for this WorkflowJob (AAP 4.7+ or legacy AWX)."""
    with _client(s) as c:
        # Merge nodes from nested route + flat list — some builds return [] on only one path.
        merged: list[dict] = []
        seen_node_ids: set[int] = set()
        for url, params in (
            (f"/api/v2/workflow_jobs/{workflow_job_id}/workflow_nodes/", {"page_size": 200}),
            ("/api/v2/workflow_job_nodes/", {"workflow_job": workflow_job_id, "page_size": 200}),
        ):
            r = c.get(url, params=params)
            if r.status_code != 200:
                continue
            for node in r.json().get("results") or []:
                nid = node.get("id")
                if isinstance(nid, int):
                    if nid in seen_node_ids:
                        continue
                    seen_node_ids.add(nid)
                merged.append(node)

        for node in merged:
            if not _node_is_workflow_approval(node):
                continue
            sj = (node.get("summary_fields") or {}).get("job") or {}
            if not _approval_status_open(sj.get("status")):
                continue
            jid = node.get("job") or sj.get("id")
            if jid is not None:
                return int(jid)

        # Legacy AWX: workflow_approval_jobs list
        r2 = c.get(
            "/api/v2/workflow_approval_jobs/",
            params={"workflow_job": workflow_job_id, "page_size": 200},
        )
        if r2.status_code != 200:
            return None
        rows = r2.json().get("results") or []
        pend = [row for row in rows if _approval_status_open(row.get("status"))]
        if not pend:
            return None
        return int(sorted(pend, key=lambda x: int(x["id"]))[0]["id"])


def workflow_job_detail(s: Settings, wf_job_id: int) -> dict:
    with _client(s) as c:
        r = c.get(f"/api/v2/workflow_jobs/{wf_job_id}/")
        r.raise_for_status()
        return r.json()


def workflow_approval_job_detail(s: Settings, approval_id: int) -> dict:
    """Fetch unified workflow approval job (AAP 4.7+ `workflow_approvals` or legacy `workflow_approval_jobs`)."""
    with _client(s) as c:
        r = c.get(f"/api/v2/workflow_approvals/{approval_id}/")
        if r.status_code == 404:
            r = c.get(f"/api/v2/workflow_approval_jobs/{approval_id}/")
        r.raise_for_status()
        return r.json()


def approve_or_deny(s: Settings, approval_job_id: int, action: str) -> None:
    if action not in ("approve", "deny"):
        raise ValueError(action)
    with _client(s) as c:
        path = f"/api/v2/workflow_approvals/{approval_job_id}/{action}/"
        r = c.post(path, json={})
        if r.status_code == 404:
            path = f"/api/v2/workflow_approval_jobs/{approval_job_id}/{action}/"
            r = c.post(path, json={})
        if r.status_code >= 400:
            raise RuntimeError(f"Controller {path} failed: {r.status_code} {r.text}")
