#!/usr/bin/env python3
"""Remove AAPEX-* exclusions whose expiration timestamp is in the past.

Never removes unexpired exceptions or AAPEX entries with no expiration
(those are owned by JT-03 / the one-shot schedule).
"""
from __future__ import annotations

import copy
import json
import os
import ssl
import sys
from datetime import datetime, timezone
import urllib.request

ACS = os.environ["ACS_URL"].rstrip("/")
TOKEN = os.environ["ACS_TOKEN"]
CTX = ssl._create_unverified_context() if os.environ.get("ACS_VALIDATE_CERTS", "true").lower() == "false" else None
POLICY_IDS = [
    "8ab0f199-4904-4808-9461-3501da1d1b77",
    "fe9de18b-86db-44d5-a7c4-74173ccffe2e",
]


def req(method: str, path: str, body=None):
    data = None if body is None else json.dumps(body).encode()
    r = urllib.request.Request(
        f"{ACS}{path}",
        data=data,
        method=method,
        headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(r, context=CTX) as resp:
        return json.load(resp)


def parse_exp(value: str) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)
    except ValueError:
        return None


now = datetime.now(timezone.utc)
changed = False
for pid in POLICY_IDS:
    pol = req("GET", f"/v1/policies/{pid}")
    keep = []
    removed = []
    for exc in pol.get("exclusions") or []:
        name = str(exc.get("name") or "")
        if not name.startswith("AAPEX-"):
            keep.append(exc)
            continue
        exp = parse_exp(str(exc.get("expiration") or ""))
        if exp is None:
            print(f"{pol['name']}: keep {name} (no parseable expiration — JT-03 owns it)")
            keep.append(exc)
            continue
        if exp > now:
            print(f"{pol['name']}: keep {name} (expires {exp.isoformat()})")
            keep.append(exc)
            continue
        removed.append(name)
    if not removed:
        continue
    body = copy.deepcopy(pol)
    for k in list(body):
        if k.startswith("SORT"):
            body.pop(k)
    body["exclusions"] = keep
    req("PUT", f"/v1/policies/{pid}", body)
    print(f"{pol['name']}: removed expired {removed}")
    changed = True

print("changed=true" if changed else "changed=false")
sys.exit(0)
