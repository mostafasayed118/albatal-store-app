#!/usr/bin/env python3
"""Validate EN/AR ARB parity and detect duplicate keys.

Uses raw line scans for true duplicates (JSON parsers collapse them)
and json.load for structural validity. Exit code 0 on success.
"""

from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EN_PATH = ROOT / "l10n" / "app_en.arb"
AR_PATH = ROOT / "l10n" / "app_ar.arb"

# Top-level message keys only (2-space indent, not metadata @keys).
TOP_KEY_RE = re.compile(r'^  "([^"@][^"]*)"\s*:')


def top_level_keys(text: str) -> list[str]:
    return TOP_KEY_RE.findall(text)


def message_keys(data: dict) -> set[str]:
    return {k for k in data if not k.startswith("@")}


def main() -> int:
    errors: list[str] = []

    for path in (EN_PATH, AR_PATH):
        if not path.is_file():
            errors.append(f"Missing ARB file: {path}")
            continue
        text = path.read_text(encoding="utf-8")
        try:
            data = json.loads(text)
        except json.JSONDecodeError as exc:
            errors.append(f"{path.name}: invalid JSON: {exc}")
            continue

        raw_keys = top_level_keys(text)
        dups = sorted(k for k, n in Counter(raw_keys).items() if n > 1)
        if dups:
            errors.append(f"{path.name}: duplicate keys: {dups}")

        # Placeholder metadata for messages that interpolate.
        for key, value in data.items():
            if key.startswith("@") or not isinstance(value, str):
                continue
            if "{" in value and f"@{key}" not in data:
                errors.append(
                    f"{path.name}: key '{key}' has placeholders but no @{key} metadata"
                )

    if EN_PATH.is_file() and AR_PATH.is_file():
        en = json.loads(EN_PATH.read_text(encoding="utf-8"))
        ar = json.loads(AR_PATH.read_text(encoding="utf-8"))
        en_keys = message_keys(en)
        ar_keys = message_keys(ar)
        missing_ar = sorted(en_keys - ar_keys)
        missing_en = sorted(ar_keys - en_keys)
        if missing_ar:
            errors.append(f"Keys in EN missing from AR: {missing_ar}")
        if missing_en:
            errors.append(f"Keys in AR missing from EN: {missing_en}")
        if not missing_ar and not missing_en:
            print(f"ARB parity OK: {len(en_keys)} message keys")

    if errors:
        print("l10n check FAILED:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    print("l10n check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
