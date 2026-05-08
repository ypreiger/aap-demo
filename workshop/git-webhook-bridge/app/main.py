"""
Bridge: GitHub push under projects/ → EDA HTTP event (optional) + Controller SCM sync +
launch gated workflow workshop-projects-git-driven (approval precedes playbook).
"""

from __future__ import annotations

import hashlib
import hmac
import json
import logging
from typing import Any

import httpx
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import PlainTextResponse
from pydantic import BaseModel, Field

from . import classify, controller as ctl
from .settings import load_settings

log = logging.getLogger("git-webhook-bridge")
logging.basicConfig(level=logging.INFO)

app = FastAPI(title="git-webhook-bridge", version="1.1.0")


def _verify_github_signature(secret: str, body: bytes, sig_header: str | None) -> None:
    if not secret.strip():
        return
    if not sig_header or not sig_header.startswith("sha256="):
        raise HTTPException(status_code=401, detail="missing signing secret")
    want = sig_header.strip().split("=", 1)[1]
    digest = hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(want, digest):
        raise HTTPException(status_code=401, detail="bad signature")


def _send_eda(s, envelope: dict[str, Any]) -> None:
    url = (s.eda_webhook_url or "").strip()
    if not url:
        return
    headers: dict[str, str] = {"Content-Type": "application/json"}
    if (s.eda_webhook_token or "").strip():
        headers["Authorization"] = f"Bearer {s.eda_webhook_token.strip()}"
    try:
        with httpx.Client(verify=s.controller_verify_ssl, timeout=30.0) as c:
            r = c.post(url, headers=headers, json=envelope)
            r.raise_for_status()
            log.info("EDA POST ok (%s)", r.status_code)
    except Exception as exc:  # noqa: BLE001
        log.warning("EDA webhook optional failure: %s", exc)


@app.get("/healthz", response_class=PlainTextResponse)
def healthz() -> str:
    return "ok"


@app.post("/v1/github")
async def github_push(request: Request) -> dict[str, Any]:
    s = load_settings()
    raw = await request.body()
    _verify_github_signature(s.github_webhook_secret, raw, request.headers.get("X-Hub-Signature-256"))

    try:
        body = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as e:
        raise HTTPException(status_code=400, detail=f"invalid json: {e}") from e

    event = (request.headers.get("X-GitHub-Event") or "").strip().lower()
    if event == "ping":
        return {"ok": True, "pong": True}
    if event and event != "push":
        return {"ignored": True, "event": event}

    paths = classify.single_head_paths(body)
    by_proj = classify.classify_projects_domains(paths)
    if not by_proj:
        return {"ignored": True, "reason": "no projects/ matches"}

    envelope = {
        "ansible_eda_event": {
            "type": "scm.projects.changed",
            "delivery": body.get("head_commit") or {},
            "ref": body.get("ref"),
            "repository": (body.get("repository") or {}).get("full_name"),
            "changed_files": sorted(paths),
            "domains_by_project": by_proj,
        }
    }

    log.info(
        "push affects projects=%s files=%s", list(by_proj.keys()), sorted(paths)[:20]
    )

    _send_eda(s, envelope)

    if not (s.controller_host and s.controller_token):
        raise HTTPException(status_code=503, detail="Controller API not configured")

    pid = ctl.find_project_id(s)
    if pid is None:
        raise HTTPException(status_code=502, detail="No SCM project matching filter")

    try:
        upd = ctl.launch_project_update(s, pid)
        log.info("Project update queued id=%s", upd.get("id"))
    except httpx.HTTPStatusError as exc:
        log.warning("Project update POST failed %s — continuing to workflow", exc.response.text)

    wtid = ctl.workflow_job_template_id(s, s.workflow_template_name)
    if wtid is None:
        raise HTTPException(
            status_code=424,
            detail=f"workflow_job_template '{s.workflow_template_name}' absent — oc apply tower CRs?",
        )

    inv_id = ctl.inventory_id_by_name(s, s.inventory_name)
    if inv_id is None:
        raise HTTPException(status_code=424, detail=f"inventory '{s.inventory_name}' missing")

    # Primary project chooses BOM path precedence (workflow still loops all changed slugs inside playbook).
    primary = sorted(by_proj.keys())[0]
    extra_vars: dict[str, Any] = {
        "git_triggered": True,
        "git_changed_files": sorted(paths),
        "domains_by_project": by_proj,
        "git_primary_project": primary,
        # convenience for older survey-style tasks
        "project_name": primary,
        "git_ref": body.get("ref"),
        "repository_full_name": (body.get("repository") or {}).get("full_name"),
    }
    mock_base = (
        request.headers.get("X-Workshop-Mock-URL")
        or s.workflow_mock_base_url_default
    ).strip().rstrip("/")
    if mock_base:
        extra_vars["workshop_mock_base_url"] = mock_base

    try:
        launch = ctl.launch_workflow(s, wtid, inv_id, extra_vars)
    except httpx.HTTPStatusError as exc:
        raise HTTPException(status_code=502, detail=f"workflow launch failed: {exc}") from exc

    return {
        "ok": True,
        "scm_project_updated": pid,
        "domains_by_project": by_proj,
        "workflow_launch": launch,
        "ansible_eda_event": envelope["ansible_eda_event"],
    }


class ClassifyPayload(BaseModel):
    paths: list[str] = Field(default_factory=list)


@app.post("/v1/test/classify-only")
async def classify_only(body: ClassifyPayload) -> dict[str, Any]:
    sset = {str(p).strip().replace("\\", "/") for p in body.paths}
    out = classify.classify_projects_domains(sset)
    return {"domains_by_project": out, "sample_paths": sorted(sset)}
