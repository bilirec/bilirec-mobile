#!/usr/bin/env python3
"""Fail an OSV Scanner JSON report only when CRITICAL findings are present."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

CRITICAL = 9.0


def _critical_label(value: Any) -> bool:
    return isinstance(value, str) and value.strip().lower() == "critical"


def _score(value: Any) -> float | None:
    try:
        if isinstance(value, bool) or value is None:
            return None
        return float(value)
    except (TypeError, ValueError):
        return None


def _severity_fields(node: dict[str, Any]):
    if "severity" in node:
        yield node["severity"]
    extra = node.get("database_specific")
    if isinstance(extra, dict) and "severity" in extra:
        yield extra["severity"]


def _is_critical_value(value: Any) -> bool:
    if _critical_label(value):
        return True
    score = _score(value)
    if score is not None and score >= CRITICAL:
        return True
    if isinstance(value, dict):
        return _is_critical_value(value.get("severity")) or _is_critical_value(
            value.get("score")
        )
    if isinstance(value, list):
        return any(_is_critical_value(item) for item in value)
    return False


def has_critical(report: Any) -> bool:
    if not isinstance(report, dict):
        return False
    for source in report.get("results") or []:
        if not isinstance(source, dict):
            continue
        for package in source.get("packages") or []:
            if not isinstance(package, dict):
                continue
            vulns = package.get("vulnerabilities") or []
            groups = package.get("groups") or []
            for group in groups:
                if not isinstance(group, dict):
                    continue
                if _is_critical_value(group.get("max_severity")):
                    return True
                if any(_is_critical_value(field) for field in _severity_fields(group)):
                    return True
            for vuln in vulns:
                if isinstance(vuln, dict) and any(
                    _is_critical_value(field) for field in _severity_fields(vuln)
                ):
                    return True
    return False


def load_report(path: Path) -> Any:
    if not path.exists() or path.stat().st_size == 0:
        return {"results": []}
    text = path.read_text(encoding="utf-8").strip()
    if not text:
        return {"results": []}
    return json.loads(text)


def run_self_test() -> int:
    high = {"results": [{"packages": [{"groups": [{"max_severity": "8.8"}]}]}]}
    critical = {"results": [{"packages": [{"groups": [{"max_severity": "9.8"}]}]}]}
    assert not has_critical(high), "High must not fail"
    assert has_critical(critical), "Critical must fail"
    assert not has_critical({"results": []})
    print("osv_fail_on_critical self-test passed")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) == 2 and argv[1] == "--self-test":
        return run_self_test()
    if len(argv) != 2:
        print(
            "usage: osv_fail_on_critical.py <osv-json> | --self-test",
            file=sys.stderr,
        )
        return 2

    if has_critical(load_report(Path(argv[1]))):
        print("CRITICAL vulnerabilities found in OSV scan", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
