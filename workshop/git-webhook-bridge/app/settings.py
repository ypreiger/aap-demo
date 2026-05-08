from __future__ import annotations

import os
from dataclasses import dataclass


def _bool_env(name: str, default: bool = False) -> bool:
    v = os.getenv(name)
    if v is None:
        return default
    return v.strip().lower() in {"1", "true", "yes", "y", "on"}


@dataclass(frozen=True)
class Settings:
    controller_host: str
    controller_token: str
    controller_verify_ssl: bool
    controller_project_name_contains: str

    eda_webhook_url: str
    eda_webhook_token: str

    github_webhook_secret: str

    workflow_template_name: str
    inventory_name: str
    workflow_mock_base_url_default: str


def load_settings() -> Settings:
    return Settings(
        controller_host=os.getenv("CONTROLLER_HOST", "").strip().rstrip("/"),
        controller_token=os.getenv("CONTROLLER_TOKEN", "").strip(),
        controller_verify_ssl=_bool_env("CONTROLLER_VERIFY_SSL", False),
        controller_project_name_contains=os.getenv(
            "CONTROLLER_PROJECT_FILTER", "AAP Demo"
        ).strip(),
        eda_webhook_url=os.getenv("EDA_WEBHOOK_URL", "").strip(),
        eda_webhook_token=os.getenv("EDA_WEBHOOK_TOKEN", "").strip(),
        github_webhook_secret=os.getenv("GITHUB_WEBHOOK_SECRET", "").strip(),
        workflow_template_name=os.getenv(
            "GIT_WORKFLOW_TEMPLATE_NAME", "workshop-projects-git-driven"
        ).strip(),
        inventory_name=os.getenv("GIT_WORKFLOW_INVENTORY_NAME", "Demo Inventory").strip(),
        workflow_mock_base_url_default=os.getenv("WORKFLOW_MOCK_BASE_URL", "").strip(),
    )
