"""Resolve a browser-usable URL for a Workflow Job detail page."""

from __future__ import annotations

from typing import Any

from .settings import Settings


def _strip_trailing_api(path: str) -> str:
    h = path.rstrip("/")
    if h.endswith("/api"):
        return h[:-4].rstrip("/")
    return h


def web_url_is_browser_friendly(val: Any) -> bool:
    """True if this looks like a UI link, not REST /api/... garbage."""
    if not isinstance(val, str):
        return False
    v = val.strip()
    if not v.lower().startswith(("http://", "https://")):
        return False
    before_hash = v.split("#", 1)[0]
    before_q = before_hash.split("?", 1)[0]
    if "/api/" in before_q.lower():
        return False
    return True


def resolve_workflow_job_browser_url(
    s: Settings,
    wf_detail: dict[str, Any],
    workflow_job_id: int,
) -> str:
    """
    Prefer Automation Controller-provided URLs; avoid ``related.url`` REST paths.

    If the API does not expose a good ``web_url`` (gateway / SPA path quirks), synthesize::

        {CONTROLLER_UI_PUBLIC_URL or controller_host_minus_/api}{path_template}
    """
    related = wf_detail.get("related")
    if isinstance(related, dict):
        # Order: jobs_web_url first on some AWX/AAP builds, then generic web_url
        for key in ("jobs_web_url", "web_url"):
            u = related.get(key)
            if web_url_is_browser_friendly(u):
                return str(u).strip()

    origin = (getattr(s, "controller_ui_public_url", "") or "").strip().rstrip("/")
    if not origin:
        origin = _strip_trailing_api(getattr(s, "controller_host", "") or "").rstrip("/")
    if not origin:
        return ""

    tmpl = (
        getattr(s, "controller_workflow_job_ui_path_template", None)
        or "/#/jobs/workflow/{workflow_job_id}"
    ).strip()
    try:
        path = tmpl.format(workflow_job_id=workflow_job_id)
    except KeyError:
        path = tmpl
    if not path.startswith("/"):
        path = "/" + path
    return origin.rstrip("/") + path
