"""Send HTML mail via SMTP (Gmail-friendly)."""

import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from .settings import Settings


def send_approval_mail(
    s: Settings,
    *,
    to_addr: str,
    subject: str,
    workflow_job_id: int,
    approval_job_id: int,
    approve_url: str,
    deny_url: str,
    controller_job_url_hint: str = "",
    workflow_template_name: str = "",
    workflow_job_name: str = "",
    approval_name: str = "",
    approval_description: str = "",
) -> None:
    ctx_lines = [
        ("Workflow job", workflow_job_id),
        ("Approval job", approval_job_id),
    ]
    if workflow_template_name:
        ctx_lines.insert(0, ("Workflow template", workflow_template_name))
    if workflow_job_name:
        ctx_lines.insert(1 if workflow_template_name else 0, ("Workflow job name", workflow_job_name))
    bullets = "".join(f"<li><strong>{k}</strong>: {v}</li>" for k, v in ctx_lines)
    appr_block = ""
    if approval_name or approval_description:
        appr_block = (
            "<h2 style=\"margin-top:20px;font-size:16px\">Approval step</h2>"
            f"<p style=\"margin:4px 0\"><strong>{approval_name or '(untitled)'}</strong></p>"
        )
        if approval_description:
            appr_block += f"<pre style=\"white-space:pre-wrap;background:#f8f9fa;padding:10px;border-radius:6px;font-size:13px\">{approval_description}</pre>"

    body_html = f"""
<html><body style="font-family:system-ui,sans-serif">
  <p>Workflow approval is waiting — review the context below, then choose an action.</p>
  <ul>
    {bullets}
  </ul>
  {appr_block}
  <p>
    <a href="{approve_url}" style="display:inline-block;padding:10px 16px;background:#198754;color:#fff;
      text-decoration:none;border-radius:6px;margin-right:8px">Approve</a>
    <a href="{deny_url}" style="display:inline-block;padding:10px 16px;background:#dc3545;color:#fff;
      text-decoration:none;border-radius:6px">Deny</a>
  </p>
  <p style="font-size:small;color:#555">If the buttons do not work, copy the links into a browser on a trusted device.</p>
  {f'<p style="font-size:small"><a href="{controller_job_url_hint}">Open in Controller</a></p>' if controller_job_url_hint else ""}
</body></html>
"""
    txt_bits = [
        f"Workflow job {workflow_job_id} approval {approval_job_id} pending.",
    ]
    if workflow_template_name:
        txt_bits.append(f"Workflow template: {workflow_template_name}")
    if workflow_job_name:
        txt_bits.append(f"Workflow job name: {workflow_job_name}")
    if approval_name:
        txt_bits.append(f"Approval: {approval_name}")
    if approval_description:
        txt_bits.append(approval_description)
    txt_bits.append(f"Approve: {approve_url}")
    txt_bits.append(f"Deny: {deny_url}")
    body_txt = "\n".join(txt_bits) + "\n"

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = s.mail_from or s.smtp_user
    msg["To"] = to_addr
    msg.attach(MIMEText(body_txt, "plain", "utf-8"))
    msg.attach(MIMEText(body_html, "html", "utf-8"))

    with smtplib.SMTP(s.smtp_host, s.smtp_port, timeout=60) as smtp:
        if s.smtp_use_tls:
            smtp.starttls()
        if s.smtp_user and s.smtp_password:
            smtp.login(s.smtp_user, s.smtp_password)
        smtp.sendmail(msg["From"], [to_addr], msg.as_string())
