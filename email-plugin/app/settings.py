"""Runtime configuration — Kubernetes injects ConfigMap + Secret keys as uppercase env."""

from __future__ import annotations

import os
from dataclasses import dataclass


def _bool_env(name: str, default: bool = False) -> bool:
    v = os.getenv(name)
    if v is None:
        return default
    return v.strip().lower() in {"1", "true", "yes", "y", "on"}


def _int_env(name: str, default: int) -> int:
    raw = os.getenv(name)
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError:
        return default


@dataclass(frozen=True)
class Settings:
    public_base_url: str
    controller_host: str
    controller_token: str
    controller_verify_ssl: bool
    signing_secret: str
    webhook_hmac_secret: str

    smtp_host: str
    smtp_port: int
    smtp_user: str
    smtp_password: str
    smtp_use_tls: bool

    mail_from: str
    default_to_email: str
    disable_smtp: bool
    token_max_age_hours: int


def load_settings() -> Settings:
    return Settings(
        public_base_url=os.getenv("PUBLIC_BASE_URL", "").strip(),
        controller_host=os.getenv("CONTROLLER_HOST", "").strip().rstrip("/"),
        controller_token=os.getenv("CONTROLLER_TOKEN", "").strip(),
        controller_verify_ssl=_bool_env("CONTROLLER_VERIFY_SSL", False),
        signing_secret=os.getenv("SIGNING_SECRET", "").strip() or "CHANGE_ME_SIGNING_SECRET",
        webhook_hmac_secret=os.getenv("WEBHOOK_HMAC_SECRET", "").strip(),
        smtp_host=os.getenv("SMTP_HOST", "smtp.gmail.com").strip(),
        smtp_port=_int_env("SMTP_PORT", 587),
        smtp_user=os.getenv("SMTP_USER", "").strip(),
        smtp_password=os.getenv("SMTP_PASSWORD", "").strip(),
        smtp_use_tls=_bool_env("SMTP_USE_TLS", True),
        mail_from=os.getenv("MAIL_FROM", "").strip(),
        default_to_email=os.getenv(
            "DEFAULT_TO_EMAIL",
            "yaakovpreiger@gmail.com",
        ).strip(),
        disable_smtp=_bool_env("DISABLE_SMTP", False),
        token_max_age_hours=_int_env("TOKEN_MAX_AGE_HOURS", 72),
    )
