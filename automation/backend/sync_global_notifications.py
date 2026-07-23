#!/usr/bin/env python3
# dash Sync global notification campaigns from JSON seed
"""Upsert global notification campaigns from JSON — run via wfrun (loads .env.local)."""

from __future__ import annotations

import argparse
import json
import os
import sys
import uuid
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent
PYTHON_BIN = REPO_ROOT / "app_codebase" / "python_base_05" / "bin"
_DEFAULT_JSON = SCRIPT_DIR / "files" / "global_notifications.json"


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


def _load_seed(path: Path) -> list[dict[str, Any]]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    messages = raw.get("messages")
    if not isinstance(messages, list):
        raise ValueError("Seed file must contain a messages array")
    return [item for item in messages if isinstance(item, dict)]


def _parse_uuid(value: str) -> uuid.UUID:
    return uuid.UUID(str(value).strip())


def sync_global_notifications(
    *,
    seed_path: Path,
    prune: bool = False,
) -> dict[str, int]:
    _ensure_python_bin_on_path()
    from core.notifications.response_config import validate_data_response
    from core.notifications.register_builtin_subtypes import (
        register_builtin_notification_subtypes,
    )
    from core.notifications.subtype_registry import reset_notification_subtypes
    from core.state.session_scope import session_scope
    from modules.notifications import notification_repository as repo

    reset_notification_subtypes()
    register_builtin_notification_subtypes()

    messages = _load_seed(seed_path)
    upserted = 0
    keep_ids: set[uuid.UUID] = set()

    with session_scope() as session:
        for item in messages:
            global_id = _parse_uuid(str(item.get("id", "")))
            keep_ids.add(global_id)
            title = str(item.get("title", "")).strip()
            body = str(item.get("body", "")).strip()
            notification_type = str(item.get("type", "instant")).strip().lower()
            category = str(item.get("category", "")).strip()
            subtype = str(item.get("subtype", "")).strip()
            source = str(item.get("source", "global_broadcast"))
            if not title or not body:
                raise ValueError(f"Message {global_id} requires title and body")
            if not category or not subtype:
                raise ValueError(f"Message {global_id} requires category and subtype")
            data_raw = item.get("data") if isinstance(item.get("data"), dict) else {}
            normalized_data = validate_data_response(
                data_raw,
                source=source,
                category=category,
                subtype=subtype,
            )
            repo.upsert_global_notification(
                session,
                global_id=global_id,
                source=source,
                notification_type=notification_type,
                title=title,
                body=body,
                category=category,
                subtype=subtype,
                msg_id=item.get("msg_id"),
                data=normalized_data,
                responses=item.get("responses") if isinstance(item.get("responses"), list) else [],
                target_audience=item.get("target_audience")
                if isinstance(item.get("target_audience"), dict)
                else {"all": True},
                is_active=bool(item.get("is_active", True)),
            )
            upserted += 1

        pruned = 0
        if prune:
            pruned = repo.deactivate_global_notifications_not_in(session, keep_ids)

    return {"upserted": upserted, "pruned": pruned}


def main() -> None:
    repo_root = _require_wfrun()
    mode = os.environ["WFRUN_MODE"]

    parser = argparse.ArgumentParser(
        description="Sync global notifications from JSON seed (wfrun → loads DATABASE_URL)",
    )
    parser.add_argument(
        "--file",
        type=Path,
        default=_DEFAULT_JSON,
        help="Path to global_notifications.json",
    )
    parser.add_argument(
        "--prune",
        action="store_true",
        help="Deactivate global campaigns not present in the seed file",
    )
    args = parser.parse_args()

    if not args.file.is_file():
        print(f"❌ Seed file not found: {args.file}", file=sys.stderr)
        sys.exit(1)

    print(f"📬 wfrun ({mode}): sync global notifications")
    print(f"   root:  {repo_root}")
    print(f"   seed:  {args.file}")
    if args.prune:
        print("   prune: yes (deactivate campaigns not in seed)")

    result = sync_global_notifications(seed_path=args.file, prune=args.prune)
    print(
        f"✅ Synced global notifications: upserted={result['upserted']} "
        f"pruned={result['pruned']}"
    )


if __name__ == "__main__":
    main()
