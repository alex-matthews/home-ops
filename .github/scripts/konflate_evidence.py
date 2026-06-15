#!/usr/bin/env python3
"""Evidence provider for Konflate's rendered PR diff."""

import json
import os
import sys
import urllib.error
import urllib.request

BASE_URL = os.environ.get("KONFLATE_URL", "https://konflate.alexmatthews.xyz").rstrip(
    "/"
)
MCP_URL = os.environ.get("KONFLATE_MCP_URL", "").strip()
PR = os.environ.get("PR_NUMBER", "").strip()
SID = None


def _emit(findings, severity="info"):
    print(json.dumps({"severity": severity, "findings": findings}))
    sys.exit(0)


def _call_mcp(method, params=None, notif=False):
    global SID

    body = {"jsonrpc": "2.0", "method": method}
    if not notif:
        body["id"] = 1
    if params is not None:
        body["params"] = params

    req = urllib.request.Request(MCP_URL, data=json.dumps(body).encode(), method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Accept", "application/json, text/event-stream")
    req.add_header("User-Agent", "home-ops-ai-review-konflate/1.0")

    token = os.environ.get("KONFLATE_MCP_TOKEN", "").strip()
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    if SID:
        req.add_header("Mcp-Session-Id", SID)

    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            sid = response.headers.get("Mcp-Session-Id")
            if sid:
                SID = sid
            raw = response.read().decode()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")[:200].replace("\n", " ")
        raise RuntimeError(f"HTTP {exc.code} from {MCP_URL}: {detail}") from None

    if notif:
        return None

    for line in raw.splitlines():
        if line.startswith("data:"):
            return json.loads(line[5:].strip())
    return None


def _get_json(path):
    req = urllib.request.Request(f"{BASE_URL}{path}", method="GET")
    req.add_header("Accept", "application/json")
    req.add_header("User-Agent", "home-ops-ai-review-konflate/1.0")
    with urllib.request.urlopen(req, timeout=20) as response:
        return json.loads(response.read().decode())


def _text(resp):
    chunks = []
    for content in (resp or {}).get("result", {}).get("content", []):
        if content.get("type") == "text":
            chunks.append(content["text"])
    return "\n".join(chunks).strip()


def _no_evidence(text):
    low = (text or "").lower()
    sentinels = (
        "no pull request",
        "is tracked",
        "no rendered diff",
        "still rendering",
        "has no rendered",
    )
    return (not text) or any(sentinel in low for sentinel in sentinels)


def _mcp_findings():
    if not MCP_URL:
        return []

    try:
        _call_mcp(
            "initialize",
            {
                "protocolVersion": "2025-06-18",
                "capabilities": {},
                "clientInfo": {
                    "name": "konflate-evidence",
                    "version": "0",
                },
            },
        )
        _call_mcp("notifications/initialized", notif=True)
        summary = _text(
            _call_mcp(
                "tools/call",
                {"name": "get_pr_summary", "arguments": {"number": int(PR)}},
            )
        )
        diff = _text(
            _call_mcp(
                "tools/call",
                {"name": "get_pr_diff", "arguments": {"number": int(PR)}},
            )
        )
    except Exception as exc:  # noqa: BLE001
        print(f"konflate MCP evidence unavailable: {exc}", file=sys.stderr)
        return []

    if _no_evidence(diff):
        return []

    source = f"{BASE_URL}/#/pr/{PR}"
    findings = [
        {
            "severity": "info",
            "message": (
                "Konflate MCP rendered Flux diff "
                "(post-kustomize/Helm Kubernetes YAML):\n\n"
                f"{diff}"
            ),
            "source": source,
        }
    ]
    if summary and not _no_evidence(summary):
        findings.append({"severity": "info", "message": summary, "source": source})
    return findings


def _short_digest(value):
    text = str(value or "")
    if text.startswith("sha256:"):
        return text[:19]
    return text[:26]


def _rest_findings():
    try:
        summary = _get_json(f"/api/prs/{PR}/summary")
    except Exception as exc:  # noqa: BLE001
        print(f"konflate REST evidence unavailable: {exc}", file=sys.stderr)
        return []

    if summary.get("status") not in {"ready", "error"}:
        return []

    diff = summary.get("diff") or {}
    source = summary.get("reviewUrl") or f"{BASE_URL}/#/pr/{PR}"
    rendered_summary = diff.get("summary") or {}
    impact = diff.get("impact") or {}
    images = diff.get("images") or []
    failures = diff.get("failures")
    warnings = diff.get("warnings")

    lines = [
        "Konflate rendered diff summary:",
        f"- status: {summary.get('status')}",
        f"- rendered head SHA: {diff.get('headSha') or summary.get('pr', {}).get('headSha') or 'unknown'}",
        (
            "- resources: "
            f"+{rendered_summary.get('added', 0)} "
            f"~{rendered_summary.get('changed', 0)} "
            f"-{rendered_summary.get('removed', 0)}"
        ),
        (
            "- impact: "
            f"{impact.get('resources', 0)} resources, "
            f"{impact.get('parents', 0)} parents, "
            f"namespaces={', '.join(impact.get('namespaces') or []) or 'none'}, "
            f"crds={impact.get('crds', 0)}"
        ),
    ]

    if images:
        lines.append("- image changes:")
        for image in images[:10]:
            refs = ", ".join(image.get("refs") or []) or "unknown workload"
            lines.append(
                "  - "
                f"{image.get('name')} "
                f"{_short_digest(image.get('from'))} -> {_short_digest(image.get('to'))} "
                f"({refs})"
            )
    else:
        lines.append("- image changes: none")

    if warnings:
        lines.append(f"- warnings: {json.dumps(warnings, sort_keys=True)}")
    else:
        lines.append("- warnings: none")

    if failures:
        lines.append(f"- render failures: {json.dumps(failures, sort_keys=True)}")
    else:
        lines.append("- render failures: none")

    try:
        full = _get_json(f"/api/prs/{PR}/diff")
    except Exception as exc:  # noqa: BLE001
        print(f"konflate resource detail unavailable: {exc}", file=sys.stderr)
        full = {}

    resources = ((full.get("diff") or {}).get("resources") or [])[:20]
    if resources:
        lines.append("- rendered resources:")
        for resource in resources:
            lines.append(
                "  - "
                f"{resource.get('title')} "
                f"({resource.get('status')}, +{resource.get('add', 0)}/-{resource.get('del', 0)})"
            )

    return [
        {
            "severity": "info",
            "message": "\n".join(lines),
            "source": source,
        }
    ]


def main():
    if not PR.isdigit():
        _emit([])

    findings = _mcp_findings() or _rest_findings()
    _emit(findings)


if __name__ == "__main__":
    main()
