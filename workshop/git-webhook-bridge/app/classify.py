"""Map changed repository paths to BOM projects and logical automation domains."""

from __future__ import annotations

from collections import defaultdict
from typing import Any


def flatten_github_commits(commits: list[dict[str, Any]]) -> set[str]:
    out: set[str] = set()
    for c in commits or []:
        for key in ("added", "removed", "modified"):
            for path in c.get(key) or []:
                if isinstance(path, str) and path.strip():
                    out.add(path.strip())
    return out


def single_head_paths(payload: dict[str, Any]) -> set[str]:
    """Best-effort paths for push events when commits[].* is sparse."""
    commits = payload.get("commits") or []
    paths = flatten_github_commits(commits)
    if paths:
        return paths
    # fallback: rely on hook head_commit
    head = payload.get("head_commit") or {}
    for key in ("added", "removed", "modified"):
        paths |= {p for p in (head.get(key) or []) if isinstance(p, str)}
    return paths


def classify_projects_domains(paths: set[str]) -> dict[str, list[str]]:
    """
    Map top-level BOM project slug (projects/<slug>/…) to domains.
    OpenShift BOM granularity:
      - openshift_ns_bootstrap: namespace/serviceaccount-like assets
      - openshift_netpol_audit: networkpolicy tweaks only
      - openshift_virt: other bom/*.yaml assets — foundation + VMs + audit (README-only edits ignored)
    Domain YAML:
      domain_firewall/domain_f5/domain_bluecoat/domain_vmware/domain_generic_yaml
    """
    dom: dict[str, set[str]] = defaultdict(set)
    for raw in paths:
        p = raw.replace("\\", "/")
        if not p.startswith("projects/"):
            continue
        parts = p.split("/")
        if len(parts) < 3:
            continue
        slug = parts[1]
        if parts[2] == "bom":
            rel = "/".join(parts[3:]).lower()
            if rel.endswith("readme.md") or "/readme.md" in rel:
                continue
            if "networkpolicy" in rel and rel.endswith(".yaml"):
                dom[slug].add("openshift_netpol_audit")
                continue
            if "namespace.yaml" in rel or "serviceaccount" in rel:
                dom[slug].add("openshift_ns_bootstrap")
                continue
            dom[slug].add("openshift_virt")
            continue
        if parts[2] == "domain":
            dom[slug].add("domain_yaml_meta")
            name = "/".join(parts[3:])
            lowered = name.lower()
            if "firewall" in lowered:
                dom[slug].add("domain_firewall")
            if lowered.startswith("f5") or "f5_" in lowered or lowered.endswith("_f5.yaml"):
                dom[slug].add("domain_f5")
            if "bluecoat" in lowered:
                dom[slug].add("domain_bluecoat")
            if "vmware" in lowered:
                dom[slug].add("domain_vmware")
            if not dom[slug] & {
                "domain_firewall",
                "domain_f5",
                "domain_bluecoat",
                "domain_vmware",
            }:
                dom[slug].add("domain_generic_yaml")
            continue

    # stable ordering
    return {k: sorted(v) for k, v in dom.items() if k}
