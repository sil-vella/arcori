#!/usr/bin/env python3
# dash Rename claimed Kin upload files GEN00N → SER00N
"""Rename on-disk claimed Kin JSON under UPLOAD_ROOT after series-token rename.

DB ids are rewritten by Alembic ``015_series_token_ser``. Claimed Kin files
live at ``{UPLOAD_ROOT}/kin/designs/{id}.json`` and
``{UPLOAD_ROOT}/kin/players/{id}.json`` — rename those filenames to match.

``UPLOAD_ROOT=/data/uploads`` is the path **inside** the API container (Docker
volume ``arcori_uploads``). When this script runs on the host via wfrun/dash,
that path usually does not exist — we then rename via ``docker exec Arcori_api``.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

REPLACES = (
    ("GEN003", "SER003"),
    ("GEN002", "SER002"),
    ("GEN001", "SER001"),
)

API_CONTAINER = os.environ.get("ARCORI_API_CONTAINER", "Arcori_api").strip() or "Arcori_api"


def _rewrite(name: str) -> str:
    out = name
    for old, new in REPLACES:
        out = out.replace(old, new)
    return out


def _rename_under(base: Path) -> int:
    renamed = 0
    for sub in ("kin/designs", "kin/players"):
        folder = base / sub
        if not folder.is_dir():
            continue
        for path in sorted(folder.glob("*.json"), key=lambda p: -len(p.name)):
            new_name = _rewrite(path.name)
            if new_name == path.name:
                continue
            dest = path.with_name(new_name)
            if dest.exists():
                print(f"skip collision {dest}")
                continue
            path.rename(dest)
            renamed += 1
            print(f"{path.name} -> {new_name}")
    return renamed


def _docker_exec_rename(container: str, upload_root: str) -> int:
    """Run the same rename logic inside the API container."""
    # Inline Python keeps one source of truth without copying the script in.
    remote = r"""
import os
from pathlib import Path
REPLACES = (("GEN003","SER003"),("GEN002","SER002"),("GEN001","SER001"))
def rewrite(name):
    out = name
    for a,b in REPLACES: out = out.replace(a,b)
    return out
base = Path(os.environ.get("UPLOAD_ROOT","/data/uploads"))
n = 0
for sub in ("kin/designs","kin/players"):
    folder = base / sub
    if not folder.is_dir():
        print(f"missing {folder}")
        continue
    for path in sorted(folder.glob("*.json"), key=lambda p: -len(p.name)):
        new_name = rewrite(path.name)
        if new_name == path.name:
            continue
        dest = path.with_name(new_name)
        if dest.exists():
            print(f"skip collision {dest}")
            continue
        path.rename(dest)
        n += 1
        print(f"{path.name} -> {new_name}")
print(f"renamed {n} files under {base}")
"""
    env = os.environ.copy()
    # Ensure container sees UPLOAD_ROOT
    cmd = [
        "docker",
        "exec",
        "-e",
        f"UPLOAD_ROOT={upload_root}",
        container,
        "python3",
        "-c",
        remote,
    ]
    print(f"UPLOAD_ROOT {upload_root!r} not on host — renaming via docker exec {container}")
    return subprocess.call(cmd, env=env)


def _resolve_local_root() -> Path | None:
    raw = os.environ.get("UPLOAD_ROOT", "").strip()
    if raw:
        p = Path(raw)
        if p.is_dir():
            return p
        # Container path leaked into host env — not usable here.
        if raw in {"/data/uploads", "data/uploads"}:
            return None
    candidate = Path(__file__).resolve().parents[2] / "docker" / "data" / "uploads"
    if candidate.is_dir():
        return candidate
    return None


def main() -> int:
    local = _resolve_local_root()
    if local is not None:
        n = _rename_under(local)
        print(f"renamed {n} files under {local}")
        return 0

    upload_root = os.environ.get("UPLOAD_ROOT", "").strip() or "/data/uploads"
    # Prefer docker exec when API is up.
    try:
        probe = subprocess.run(
            ["docker", "inspect", "-f", "{{.State.Running}}", API_CONTAINER],
            capture_output=True,
            text=True,
            check=False,
        )
        running = probe.stdout.strip().lower() == "true"
    except FileNotFoundError:
        running = False

    if running:
        return _docker_exec_rename(API_CONTAINER, upload_root)

    print(
        f"❌ UPLOAD_ROOT {upload_root!r} is not a host directory, and "
        f"container {API_CONTAINER!r} is not running.\n"
        "Start Docker (Arcori_api) and re-run, or set UPLOAD_ROOT to a real host path.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
