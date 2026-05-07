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
) -> None:
    body_html = f"""
<html><body style="font-family:system-ui,sans-serif">
  <p>Workflow approval is waiting in Ansible Automation Platform.</p>
  <ul>
    <li><strong>Workflow job</strong>: {workflow_job_id}</li>
    <li><strong>Approval job</strong>: {approval_job_id}</li>
  </ul>
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
    body_txt = (
        f"Workflow job {workflow_job_id} approval {approval_job_id} pending.\n"
        f"Approve: {approve_url}\nDeny: {deny_url}\n"
    )

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
