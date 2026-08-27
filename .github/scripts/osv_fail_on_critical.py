#!/usr/bin/env python3
"""Fail an OSV Scanner JSON report only when CRITICAL findings are present."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Iterable

CRITICAL_THRESHOLD = 9.0
FIXTURES_DIR = Path(__file__).resolve().parent / "fixtures"


def _is_critical_label(value: Any) -> bool:
    return isinstance(value, str) and value.strip().lower() == "critical"


def _parse_score(value: Any) -> float | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if not isinstance(value, str):
        return None
    text = value.strip()
    if not text:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def _iter_severity_fields(node: dict[str, Any]) -> Iterable[Any]:
    if "severity" in node:
        yield node["severity"]
    database_specific = node.get("database_specific")
    if isinstance(database_specific, dict) and "severity" in database_specific:
        yield database_specific["severity"]
    ecosystem_specific = node.get("ecosystem_specific")
    if isinstance(ecosystem_specific, dict) and "severity" in ecosystem_specific:
        yield ecosystem_specific["severity"]


def _labels_from_severity(value: Any) -> Iterable[str]:
    if isinstance(value, str):
        yield value
        return
    if isinstance(value, dict):
        for key in ("severity", "score"):
            inner = value.get(key)
            if isinstance(inner, str):
                yield inner
        return
    if isinstance(value, list):
        for item in value:
            yield from _labels_from_severity(item)


def _scores_from_severity(value: Any) -> Iterable[float]:
    parsed = _parse_score(value)
    if parsed is not None:
        yield parsed
        return
    if isinstance(value, dict):
        nested = _parse_score(value.get("score"))
        if nested is not None:
            yield nested
        return
    if isinstance(value, list):
        for item in value:
            yield from _scores_from_severity(item)


def _is_critical_finding(
    group: dict[str, Any],
    vulnerabilities: list[Any] | None = None,
) -> bool:
    max_severity = group.get("max_severity")
    if _is_critical_label(max_severity):
        return True
    max_score = _parse_score(max_severity)
    if max_score is not None and max_score >= CRITICAL_THRESHOLD:
        return True

    for field in _iter_severity_fields(group):
        if any(_is_critical_label(label) for label in _labels_from_severity(field)):
            return True
        if any(score >= CRITICAL_THRESHOLD for score in _scores_from_severity(field)):
            return True

    for vuln in vulnerabilities or []:
        if not isinstance(vuln, dict):
            continue
        for field in _iter_severity_fields(vuln):
            if any(_is_critical_label(label) for label in _labels_from_severity(field)):
                return True
            if any(score >= CRITICAL_THRESHOLD for score in _scores_from_severity(field)):
                return True
    return False


def report_has_critical(report: Any) -> bool:
    if not isinstance(report, dict):
        return False
    results = report.get("results")
    if not isinstance(results, list):
        return False

    for source in results:
        if not isinstance(source, dict):
            continue
        packages = source.get("packages")
        if not isinstance(packages, list):
            continue
        for package in packages:
            if not isinstance(package, dict):
                continue
            vulns = package.get("vulnerabilities")
            vuln_list = vulns if isinstance(vulns, list) else None
            groups = package.get("groups")
            if isinstance(groups, list) and groups:
                for group in groups:
                    if isinstance(group, dict) and _is_critical_finding(
                        group, vuln_list
                    ):
                        return True
            elif vuln_list:
                if _is_critical_finding({}, vuln_list):
                    return True
    return False


def exit_code_for_report(report: Any) -> int:
    return 1 if report_has_critical(report) else 0


def load_report(path: Path) -> Any:
    if not path.exists() or path.stat().st_size == 0:
        return {"results": []}
    text = path.read_text(encoding="utf-8").strip()
    if not text:
        return {"results": []}
    return json.loads(text)


def run_self_test() -> int:
    high = json.loads((FIXTURES_DIR / "osv_high.json").read_text(encoding="utf-8"))
    critical = json.loads(
        (FIXTURES_DIR / "osv_critical.json").read_text(encoding="utf-8")
    )
    empty = json.loads((FIXTURES_DIR / "osv_empty.json").read_text(encoding="utf-8"))

    assert exit_code_for_report(high) == 0, "High must exit 0"
    assert exit_code_for_report(critical) == 1, "Critical must exit 1"
    assert exit_code_for_report(empty) == 0, "empty report must exit 0"
    assert exit_code_for_report({"results": []}) == 0
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

    report = load_report(Path(argv[1]))
    code = exit_code_for_report(report)
    if code == 1:
        print("CRITICAL vulnerabilities found in OSV scan", file=sys.stderr)
    return code


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
