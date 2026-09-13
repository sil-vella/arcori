#!/usr/bin/env python3
# dash Run Alembic migrations (upgrade head)
"""Apply Alembic migrations via wfrun / dashup.

Uses MIGRATION_DATABASE_URL (preferred) or DATABASE_URL from the loaded
.env.local / .env.prod. Wraps app_codebase/python_base_05/bin/migrate.py.

Docker stack entrypoint also runs `alembic upgrade head` on container start;
use this when you want to migrate without restarting the API container.
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent
PYTHON_ROOT = REPO_ROOT / "app_codebase" / "python_base_05"
MIGRATE_PY = PYTHON_ROOT / "bin" / "migrate.py"


def _require_wfrun() -> None:
    root = os.environ.get("WFRUN_ROOT", "").strip()
    mode = os.environ.get("WFRUN_MODE", "").strip()
    if not root or not mode:
        print(
            "❌ Run via wfrun / dashup — this script expects WFRUN_ROOT and WFRUN_MODE.",
            file=sys.stderr,
        )
        sys.exit(1)
    migration_url = os.environ.get("MIGRATION_DATABASE_URL", "").strip()
    if migration_url:
        os.environ["DATABASE_URL"] = migration_url
        os.environ["MIGRATION_DATABASE_URL"] = migration_url
    elif not os.environ.get("DATABASE_URL", "").strip():
        print(
            "❌ DATABASE_URL or MIGRATION_DATABASE_URL not set — wfrun should load .env.",
            file=sys.stderr,
        )
        sys.exit(1)
    else:
        os.environ["MIGRATION_DATABASE_URL"] = os.environ["DATABASE_URL"].strip()


def _alembic(*args: str) -> int:
    env = os.environ.copy()
    return subprocess.call(
        [sys.executable, "-m", "alembic", *args],
        cwd=str(PYTHON_ROOT),
        env=env,
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Run Alembic migrations (wfrun / dash).",
    )
    parser.add_argument(
        "action",
        nargs="?",
        default="upgrade",
        choices=("upgrade", "current", "heads", "history"),
        help="upgrade (default) | current | heads | history",
    )
    args = parser.parse_args()
    _require_wfrun()

    if not MIGRATE_PY.is_file():
        print(f"❌ Missing {MIGRATE_PY}", file=sys.stderr)
        sys.exit(1)

    if args.action == "upgrade":
        print(f"→ alembic upgrade head  ({PYTHON_ROOT})")
        # Prefer the dedicated migrate helper (same as IDE / docs).
        rc = subprocess.call([sys.executable, str(MIGRATE_PY)], cwd=str(PYTHON_ROOT))
        if rc == 0:
            print("✓ migrations at head")
        sys.exit(rc)

    print(f"→ alembic {args.action}")
    sys.exit(_alembic(args.action))


if __name__ == "__main__":
    main()
