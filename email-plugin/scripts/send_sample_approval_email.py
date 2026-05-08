#!/usr/bin/env python3
"""
Emit the same approval mail HTML/content as runtime, or deliver one test message via SMTP.

Preview (stdout = HTML fragment — open in browser or `.html` file):

  cd email-plugin
  python3 scripts/send_sample_approval_email.py --print-html

Real send (Gmail App Password):

  cd email-plugin
  SMTP_PASSWORD='…' SMTP_USER='yaakovpreiger@gmail.com' \\
    DEFAULT_TO_EMAIL='yaakovpreiger@gmail.com' \\
    MAIL_FROM='yaakovpreiger@gmail.com' \\
    python3 scripts/send_sample_approval_email.py
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def _prepend_app_path() -> None:
    root = Path(__file__).resolve().parents[1]
    sys.path.insert(0, str(root))


def main() -> None:
    _prepend_app_path()
    parser = argparse.ArgumentParser(description="Sample AAP approval notification email.")
    parser.add_argument("--print-html", action="store_true", help="Print HTML to stdout; no SMTP.")
    parser.add_argument(
        "--approve-url",
        default="https://email-plugin-aap.apps.cluster-jx4b7.dynamic.redhatworkshops.io/v1/actions/approve?token=SAMPLE_APPROVE_TOKEN",
    )
    parser.add_argument(
        "--deny-url",
        default="https://email-plugin-aap.apps.cluster-jx4b7.dynamic.redhatworkshops.io/v1/actions/deny?token=SAMPLE_DENY_TOKEN",
    )
    args = parser.parse_args()

    from app.mailer import build_approval_mail_bodies, send_approval_mail
    from app.settings import load_settings
    from app.ui_links import resolve_workflow_job_browser_url

    s = load_settings()
    subj = f"{s.email_subject_prefix} Sample — how approval mail looks — wf #99 / approval #999"
    wf_id, ap_id = 99, 999
    ctrl_hint = resolve_workflow_job_browser_url(s, {}, wf_id)

    kw = dict(
        workflow_job_id=wf_id,
        approval_job_id=ap_id,
        approve_url=args.approve_url,
        deny_url=args.deny_url,
        controller_job_url_hint=ctrl_hint,
        workflow_template_name="bom-project-deploy",
        workflow_job_name="bom-project-deploy",
        approval_name="bom-approve-before-vms",
        approval_description="Sample only — Approve continues to VM job; Deny stops the workflow.",
    )

    if args.print_html:
        _, html = build_approval_mail_bodies(**kw)
        sys.stdout.write(html)
        return

    if s.disable_smtp or not (s.smtp_user and s.smtp_password):
        print(
            "SMTP not configured: set SMTP_PASSWORD (Gmail App Password), SMTP_USER, "
            "or run with --print-html.\n",
            f"disable_smtp={s.disable_smtp} user={bool(s.smtp_user)} password={bool(s.smtp_password)}",
            file=sys.stderr,
        )
        sys.exit(1)

    send_approval_mail(
        s,
        to_addr=s.default_to_email,
        subject=subj,
        **kw,
    )
    print(f"Sent sample to {s.default_to_email}", file=sys.stderr)


if __name__ == "__main__":
    main()
