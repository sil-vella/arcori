#!/usr/bin/env python3
"""Optionally shrink Kin template Lotties with a **uniform** scale (layout-safe).

Prefer restoring from designs via ``restore_kin_lottie_templates.py`` instead of
shrinking authored templates. Claim bake already downscales on write.

Usage (repo root):
  python3 automation/backend/shrink_kin_lottie_templates.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
KIN_ROOT = REPO / "assets" / "lottie" / "kin" / "ser001"
BIN = REPO / "app_codebase" / "python_base_05" / "bin"


def main() -> int:
    sys.path.insert(0, str(BIN))
    from modules.avari.kin_lottie_optimize import optimize_lottie_payload

    if not KIN_ROOT.is_dir():
        print(f"missing {KIN_ROOT}", file=sys.stderr)
        return 1

    print(
        "NOTE: uses uniform composition+asset scale only. "
        "For broken layouts, run restore_kin_lottie_templates.py first."
    )

    paths = sorted(
        p
        for p in KIN_ROOT.rglob("*.json")
        if p.name not in {"embeds.json", "kins.json", "customs.json"}
        and "00embeds" not in p.parts
        and "00backgrounds" not in p.parts
    )
    if not paths:
        print("no template Lottie JSON found")
        return 0

    total_before = 0
    total_after = 0
    for path in paths:
        before = path.stat().st_size
        total_before += before
        data = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            continue
        optimized = optimize_lottie_payload(data)
        text = json.dumps(optimized, ensure_ascii=False, separators=(",", ":"))
        path.write_text(text, encoding="utf-8")
        after = path.stat().st_size
        total_after += after
        ratio = (after / before * 100) if before else 0
        print(
            f"{path.relative_to(REPO)}  {before/1024:.0f}KB → {after/1024:.0f}KB ({ratio:.0f}%)"
        )

    print(
        f"TOTAL  {total_before/1024/1024:.2f}MB → {total_after/1024/1024:.2f}MB "
        f"({(total_after/total_before*100) if total_before else 0:.0f}%)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
