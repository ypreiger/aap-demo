"""
email-plugin: Webhook from Automation Controller → Gmail with signed Approve/Deny → Controller API.
"""

from __future__ import annotations

import hashlib
import hmac
import httpx
import json
import logging
import re
from functools import lru_cache
from typing import Any

from urllib.parse import quote

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import HTMLResponse, PlainTextResponse

from . import controller as ctl
from .mailer import send_approval_mail
from .settings import Settings, load_settings
from .tokens import sign_action, verify

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("email-plugin")


@lru_cache
def get_settings() -> Settings:
    return load_settings()


app = FastAPI(title="email-plugin", version="1.0.0")


def verify_inbound_hmac(s: Settings, provided_sig_header: str | None, raw_body: bytes) -> None:
    secret = (s.webhook_hmac_secret or "").strip()
    if not secret:
        return
    if not provided_sig_header:
        raise HTTPException(status_code=401, detail="missing X-Email-Plugin-Signature")
    expect = "sha256=" + hmac.new(secret.encode(), raw_body, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(provided_sig_header.strip(), expect):
        raise HTTPException(status_code=401, detail="bad webhook signature")


def _coerce_payload(data: Any) -> dict[str, Any]:
    """Turn tower webhook payloads into a flat-ish dict."""
    if isinstance(data, dict):
        return data
    if isinstance(data, str):
        try:
            return json.loads(data)
        except json.JSONDecodeError:
            raise HTTPException(status_code=400, detail="Body is not JSON object")
    raise HTTPException(status_code=400, detail="Unsupported JSON root type")


def _workflow_id_from_url(job_url: str | None) -> int | None:
    if not job_url:
        return None
    m = re.search(r"/#/jobs/workflow/(\d+)", job_url)
    if m:
        return int(m.group(1))
    m2 = re.search(r"/#/jobs/system_job_templates/.*/workflow_job/(\d+)", job_url)
    return int(m2.group(1)) if m2 else None


def extract_ids(data: dict[str, Any]) -> tuple[int | None, int | None, str | None]:
    """
    Best-effort parse for webhook JSON.
    Prefer explicit approval_job_id; else workflow_job_id for resolver.
    Override recipient: 'to_email' | 'recipient' | OVERRIDE_TO_EMAIL optional.
    """
    to_ov = (
        data.get("to_email")
        or data.get("recipient")
        or data.get("notify_to")
        or data.get("override_to_email")
    )
    ap = data.get("approval_job_id")
    wf = data.get("workflow_job_id") or data.get("workflow_job")
    if isinstance(wf, dict):
        wf = wf.get("id")
    job = data.get("job") or {}
    if isinstance(job, dict):
        if ap is None and job.get("type") in {"workflow_approval"}:
            ap = job.get("id")
            sum_wf = (job.get("summary_fields") or {}).get("workflow_job") or {}
            if wf is None and isinstance(sum_wf, dict):
                wf = sum_wf.get("id")
        elif wf is None and job.get("type") == "workflow_job":
            wf = job.get("id")
    summary = data.get("summary_fields") or {}
    wf_s = summary.get("workflow_job") if isinstance(summary, dict) else None
    if wf is None and isinstance(wf_s, dict):
        wf = wf_s.get("id")
    if wf is None:
        wf = _workflow_id_from_url(str(data.get("url") or ""))
        if wf is None and isinstance(job, dict):
            wf = _workflow_id_from_url(str(job.get("url") or ""))
    # Top-level Tower-style id can be playbook or WFJ — unreliable; only use with explicit type hints
    if ap is None and data.get("type") == "workflow_approval_job":
        ap = data.get("id")

    aa = int(ap) if ap is not None else None
    ww = int(wf) if wf is not None else None
    to_s = str(to_ov).strip() if to_ov else None
    return ww, aa, to_s


def _coerce_optional_int(v: Any) -> int | None:
    if v is None:
        return None
    if isinstance(v, int):
        return v
    if isinstance(v, str) and v.isdigit():
        return int(v)
    return None


@app.get("/healthz", response_class=PlainTextResponse)
def healthz() -> str:
    return "ok"


@app.post("/v1/hooks/controller")
async def controller_hook(request: Request) -> dict[str, Any]:
    """Automation Controller webhook (POST JSON). Customize body in notification template."""
    s = get_settings()
    if not (s.controller_host and s.controller_token):
        raise HTTPException(
            status_code=503,
            detail="Controller API not configured: set CONTROLLER_HOST (ConfigMap) and CONTROLLER_TOKEN (Secret).",
        )
    raw = await request.body()
    verify_inbound_hmac(s, request.headers.get("X-Email-Plugin-Signature"), raw)
    try:
        body = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as e:
        raise HTTPException(status_code=400, detail=f"invalid JSON: {e}") from e

    data = _coerce_payload(body)
    wf_job_id, approval_job_id, to_override = extract_ids(data)

    if approval_job_id is None and wf_job_id is None:
        raise HTTPException(
            status_code=422,
            detail="Need workflow_job_id and/or approval_job_id in webhook JSON — see README Jinja snippet.",
        )

    if approval_job_id is None and wf_job_id is not None:
        approval_job_id = ctl.first_pending_workflow_approval_id(s, wf_job_id)
        if approval_job_id is None:
            raise HTTPException(
                status_code=422,
                detail=f"No pending workflow approval found for workflow_job_id={wf_job_id}.",
            )

    try:
        appr = ctl.workflow_approval_job_detail(s, approval_job_id)
    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            raise HTTPException(
                status_code=422,
                detail=f"workflow approval id {approval_job_id} not found (wrong id or already finished).",
            ) from e
        raise HTTPException(
            status_code=502,
            detail=f"Controller API HTTP {e.response.status_code} fetching approval job.",
        ) from e

    if wf_job_id is None:
        wf_job_id = ctl.workflow_job_id_from_approval(appr)
        if wf_job_id is None:
            raise HTTPException(
                status_code=422,
                detail="Cannot resolve workflow_job_id from Controller API for this approval job.",
            )

    try:
        wf_detail = ctl.workflow_job_detail(s, wf_job_id)
    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            raise HTTPException(
                status_code=422,
                detail=f"workflow_jobs/{wf_job_id} not found.",
            ) from e
        raise HTTPException(
            status_code=502,
            detail=f"Controller API HTTP {e.response.status_code} fetching workflow job.",
        ) from e
    controller_url_hint = (
        wf_detail.get("related", {}).get("web_url")
        or wf_detail.get("url")
        or (wf_detail.get("related", {}).get("ui_url") if isinstance(wf_detail.get("related"), dict) else "")
        or ""
    )

    max_age = s.token_max_age_hours * 3600
    approve_tok = sign_action(s.signing_secret, approval_job_id, "approve", max_age)
    deny_tok = sign_action(s.signing_secret, approval_job_id, "deny", max_age)
    base = s.public_base_url.rstrip("/")
    approve_url = f"{base}/v1/actions/approve?token={quote(approve_tok, safe='')}"
    deny_url = f"{base}/v1/actions/deny?token={quote(deny_tok, safe='')}"

    to_addr = to_override or s.default_to_email
    subj = f"[AAP] Approve workflow job {wf_job_id} (approval {approval_job_id})"

    if s.disable_smtp or not ((s.smtp_user or "").strip() and (s.smtp_password or "").strip()):
        log.warning(
            "SMTP disabled or incomplete — skipping email (set disable_smtp=false and Secret smtp_* for Gmail)."
        )
    else:
        send_approval_mail(
            s,
            to_addr=to_addr,
            subject=subj,
            workflow_job_id=wf_job_id,
            approval_job_id=approval_job_id,
            approve_url=approve_url,
            deny_url=deny_url,
            controller_job_url_hint=str(controller_url_hint),
        )
        log.info("Sent approval mail to %s wf_job=%s approval=%s", to_addr, wf_job_id, approval_job_id)
    return {"ok": True, "to": to_addr, "workflow_job_id": wf_job_id, "approval_job_id": approval_job_id}


def _html_result(title: str, detail: str, job_url: str = "") -> str:
    link = f'<p><a href="{job_url}">Open Controller</a></p>' if job_url else ""
    return f"""<!DOCTYPE html><html><head><meta charset="utf-8"><title>{title}</title></head>
<body style="font-family:system-ui,sans-serif;padding:24px">
<h1>{title}</h1><p>{detail}</p>{link}</body></html>"""


@app.get("/v1/actions/approve", response_class=HTMLResponse)
async def approve_action(token: str) -> HTMLResponse:
    s = get_settings()
    try:
        aid, _ = verify(s.signing_secret, token, s.token_max_age_hours * 3600)
        ctl.approve_or_deny(s, aid, "approve")
        ap = ctl.workflow_approval_job_detail(s, aid)
        wf_job_id = ctl.workflow_job_id_from_approval(ap)
        if wf_job_id is None:
            raise HTTPException(status_code=500, detail="Controller response missing workflow_job on approval.")
        wf = ctl.workflow_job_detail(s, wf_job_id)
        hint = wf.get("related", {}).get("web_url") or wf.get("url") or ""
        return HTMLResponse(_html_result("Approved", f"Approval job {aid} was approved.", str(hint)))
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e


@app.get("/v1/actions/deny", response_class=HTMLResponse)
async def deny_action(token: str) -> HTMLResponse:
    s = get_settings()
    try:
        aid, _ = verify(s.signing_secret, token, s.token_max_age_hours * 3600)
        ctl.approve_or_deny(s, aid, "deny")
        ap = ctl.workflow_approval_job_detail(s, aid)
        wf_job_id = ctl.workflow_job_id_from_approval(ap)
        if wf_job_id is None:
            raise HTTPException(status_code=500, detail="Controller response missing workflow_job on approval.")
        wf = ctl.workflow_job_detail(s, wf_job_id)
        hint = wf.get("related", {}).get("web_url") or wf.get("url") or ""
        return HTMLResponse(_html_result("Denied", f"Approval job {aid} was denied.", str(hint)))
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
