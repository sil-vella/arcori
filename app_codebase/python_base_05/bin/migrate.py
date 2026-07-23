"""Run Alembic migrations against MIGRATION_DATABASE_URL (local IDE workflow)."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[1]


def _migration_url() -> str:
    url = os.environ.get("MIGRATION_DATABASE_URL", "").strip()
    if url:
        return url
    return os.environ.get("DATABASE_URL", "").strip()


def main() -> None:
    url = _migration_url()
    if not url:
        print(
            "MIGRATION_DATABASE_URL or DATABASE_URL must be set (e.g. from .env.local)",
            file=sys.stderr,
        )
        sys.exit(1)
    env = os.environ.copy()
    env["MIGRATION_DATABASE_URL"] = url
    subprocess.check_call(
        [sys.executable, "-m", "alembic", "upgrade", "head"],
        cwd=_ROOT,
        env=env,
    )


if __name__ == "__main__":
    main()
