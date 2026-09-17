#!/usr/bin/env python3
"""Validate GIANTS l10n XML without claiming untranslated English is translated.

Exit status 1 blocks a build on malformed XML, duplicate/empty keys, parity or
placeholder differences. Identical-to-English strings are counted separately;
proper names, acronyms, and intentional English fallback are not syntax errors.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

PRINTF = re.compile(r"%(?:\d+\$)?[-+# 0]*(?:\d+|\*)?(?:\.(?:\d+|\*))?[cdiouxXeEfgGqs]")
BRACES = re.compile(r"\{(?:[a-zA-Z_]\w*|\d+)(?::[^{}]+)?\}")


def placeholders(value: str) -> tuple[tuple[str, ...], tuple[str, ...]]:
    value = value.replace("%%", "")
    # Lua string.format is positional; order, width, and precision must survive.
    return tuple(PRINTF.findall(value)), tuple(sorted(BRACES.findall(value)))


def read_locale(path: Path) -> tuple[dict[str, str], list[str]]:
    errors: list[str] = []
    values: dict[str, str] = {}
    try:
        root = ET.parse(path).getroot()
    except (ET.ParseError, OSError) as exc:
        return values, [f"{path.name}: XML/read error: {exc}"]
    if root.tag != "l10n" or root.find("texts") is None:
        errors.append(f"{path.name}: expected <l10n><texts>")
    for item in root.findall("texts/text"):
        name, text = item.get("name"), item.get("text")
        if not name or not name.strip():
            errors.append(f"{path.name}: empty/missing key")
            continue
        if name in values:
            errors.append(f"{path.name}: duplicate key {name}")
        if text is None or not text.strip():
            errors.append(f"{path.name}: empty translation {name}")
        values[name] = text or ""
        if "\ufffd" in values[name]:
            errors.append(f"{path.name}: Unicode replacement character in {name}")
        if values[name].startswith("Missing '"):
            errors.append(f"{path.name}: stored missing-key placeholder {name}")
    return values, errors


def validate(directory: Path, required: list[str] | None = None, require_active: bool = False) -> dict:
    master_path = directory / "l10n_en.xml"
    master, errors = read_locale(master_path)
    report = {"masterKeys": len(master), "languages": {}, "errors": errors}
    files = sorted(directory.glob("l10n_*.xml"))
    if not files:
        report["errors"].append(f"{directory}: no locale files")
    for file in files:
        language = file.stem[5:]
        values, issues = read_locale(file)
        report["errors"].extend(issues)
        missing = sorted(master.keys() - values.keys())
        extra = sorted(values.keys() - master.keys())
        for key in missing:
            report["errors"].append(f"{file.name}: missing key {key}")
        for key in extra:
            report["errors"].append(f"{file.name}: unknown key {key}")
        for key in master.keys() & values.keys():
            if placeholders(master[key]) != placeholders(values[key]):
                report["errors"].append(f"{file.name}: placeholder mismatch {key}")
        same = sum(values.get(key) == text for key, text in master.items())
        report["languages"][language] = {
            "keys": len(values), "missing": len(missing), "extra": len(extra),
            "differentFromEnglish": len(master) - same - len(missing),
            "identicalToEnglish": same,
        }
    for language in required or []:
        if language not in report["languages"]:
            report["errors"].append(f"Required locale missing: {language}")
    if require_active:
        manifest_path=directory / "translationCoverage.json"
        try:
            manifest=json.loads(manifest_path.read_text(encoding="utf-8"))
            active=set(manifest["activeKeys"])
            report["activeKeys"]=len(active)
            if not active or not active.issubset(master):
                report["errors"].append("Active translation scope is empty or contains unknown master keys")
            for language in report["languages"]:
                reviewed=set(manifest.get("languages",{}).get(language,{}).get("localized",[]))
                missing=sorted(active-reviewed)
                report["languages"][language]["activeMissing"]=len(missing)
                if missing:
                    report["errors"].append(f"{language}: unlocalized active keys: {', '.join(missing)}")
        except (OSError,ValueError,KeyError,TypeError) as exc:
            report["errors"].append(f"Active translation manifest error: {exc}")
    report["ok"] = not report["errors"]
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", nargs="?", type=Path, default=Path(__file__).resolve().parents[1] / "l10n")
    parser.add_argument("--required", default="", help="Comma-separated engine locale codes")
    parser.add_argument("--report", type=Path)
    parser.add_argument("--require-active-translations", action="store_true", help="Require reviewed translation coverage for every active interface key")
    args = parser.parse_args()
    report = validate(args.directory, [x.strip() for x in args.required.split(",") if x.strip()], args.require_active_translations)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    for error in report["errors"]:
        print("ERROR " + error)
    print(f"{'PASS' if report['ok'] else 'FAIL'} localization: {len(report['languages'])} languages, {report['masterKeys']} master keys, {len(report['errors'])} errors")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
