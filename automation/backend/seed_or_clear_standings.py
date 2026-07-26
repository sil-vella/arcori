#!/usr/bin/env python3
# dash Seed or clear standings for Tiger Genesis
"""Interactive seed/clear of synthetic standings for ANM-TIG-GEN001-0001 — run via wfrun."""

from __future__ import annotations

import argparse
import os
import random
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent
PYTHON_BIN = REPO_ROOT / "app_codebase" / "python_base_05" / "bin"

TIGER_INTERNAL_ID = "ANM-TIG-GEN001-0001"
TIGER_GENERATION_NUMBER = 1
TIGER_GENERATION_ROMAN = "I"


def _require_wfrun() -> Path:
    root = os.environ.get("WFRUN_ROOT", "").strip()
    mode = os.environ.get("WFRUN_MODE", "").strip()
    if not root or not mode:
        print(
            "❌ Run via wfrun — this script expects WFRUN_ROOT and WFRUN_MODE.",
            file=sys.stderr,
        )
        sys.exit(1)
    migration_url = os.environ.get("MIGRATION_DATABASE_URL", "").strip()
    if migration_url:
        os.environ["DATABASE_URL"] = migration_url
    elif not os.environ.get("DATABASE_URL", "").strip():
        print(
            "❌ DATABASE_URL or MIGRATION_DATABASE_URL not set — wfrun should load .env.",
            file=sys.stderr,
        )
        sys.exit(1)
    return Path(root)


def _ensure_python_bin_on_path() -> None:
    bin_dir = str(PYTHON_BIN)
    if bin_dir not in sys.path:
        sys.path.insert(0, bin_dir)


def _prompt_action(explicit: str | None) -> str:
    if explicit:
        return explicit.strip().lower()
    print()
    print(f"Standings for {TIGER_INTERNAL_ID} (Animals / Genesis / gen {TIGER_GENERATION_NUMBER})")
    print("  1) seed  — clear then insert random fill + synthetic ranks")
    print("  2) clear — remove standings for this design/generation")
    raw = input("Choose [seed/clear]: ").strip().lower()
    if raw in {"1", "s", "seed"}:
        return "seed"
    if raw in {"2", "c", "clear"}:
        return "clear"
    print(f"❌ Unknown choice: {raw!r} (use seed or clear)", file=sys.stderr)
    sys.exit(1)


def _seed_tiger() -> dict:
    _ensure_python_bin_on_path()
    from modules.standings.standings_service import replace_design_standings

    n_ranks = random.randint(3, 8)
    points = sorted(
        (random.randint(10, 500) for _ in range(n_ranks)),
        reverse=True,
    )
    ranks = [
        {
            "rank": i + 1,
            "display_label": f"Seed Player {i + 1}",
            "mastery_points": points[i],
        }
        for i in range(n_ranks)
    ]
    fill_cap = 1000
    fill_current = random.randint(1, fill_cap)
    window_end = datetime.now(timezone.utc) + timedelta(days=random.randint(1, 30))
    return replace_design_standings(
        TIGER_INTERNAL_ID,
        generation_number=TIGER_GENERATION_NUMBER,
        generation_roman=TIGER_GENERATION_ROMAN,
        fill_current=fill_current,
        fill_cap=fill_cap,
        leader_window_ends_at=window_end,
        ranks=ranks,
    )


def _clear_tiger() -> dict:
    _ensure_python_bin_on_path()
    from modules.standings.standings_service import clear_design_standings

    return clear_design_standings(
        TIGER_INTERNAL_ID,
        generation_number=TIGER_GENERATION_NUMBER,
    )


def main() -> None:
    repo_root = _require_wfrun()
    mode = os.environ["WFRUN_MODE"]

    parser = argparse.ArgumentParser(
        description=(
            "Seed or clear synthetic standings for Tiger Genesis "
            f"({TIGER_INTERNAL_ID})"
        ),
    )
    parser.add_argument(
        "action",
        nargs="?",
        choices=("seed", "clear"),
        help="seed or clear (prompts if omitted)",
    )
    args = parser.parse_args()
    action = _prompt_action(args.action)

    print(f"🏆 wfrun ({mode}): standings {action}")
    print(f"   root:   {repo_root}")
    print(f"   design: {TIGER_INTERNAL_ID}")

    if action == "seed":
        payload = _seed_tiger()
        print(
            f"✅ Seeded standings: fill={payload['fill']['current']}/"
            f"{payload['fill']['cap']} ranks={len(payload['ranks'])}"
        )
    else:
        result = _clear_tiger()
        print(f"✅ Cleared standings: deleted={result['deleted']}")


if __name__ == "__main__":
    main()
