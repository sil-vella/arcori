#!/usr/bin/env python3
# dash Catalog: scan / import theme JSON → catalog_designs
"""Scan authored theme JSON for designs missing from Postgres; prompt to import.

Always lists new internalIds + total count, then asks whether to insert.
Pass --apply to skip the prompt (non-interactive).

Run via wfrun (loads DATABASE_URL).
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent
PYTHON_BIN = REPO_ROOT / "app_codebase" / "python_base_05" / "bin"


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


def _scan() -> tuple[list[dict], int, int, bool]:
    """Return (new_entries, new_count, authored_total, table_empty)."""
    from core.state.session_scope import session_scope
    from modules.catalog.catalog_authoring import iter_authored_designs
    from modules.catalog import catalog_repository as catalog_repo

    authored = iter_authored_designs()
    with session_scope() as session:
        existing = catalog_repo.all_internal_ids(session)
        table_empty = len(existing) == 0
        new_entries: list[dict] = []
        for entry in authored:
            design = entry["design"]
            iid = str(design.get("internalId") or "").strip()
            if not iid or iid in existing:
                continue
            new_entries.append(entry)
        return new_entries, len(new_entries), len(authored), table_empty


def _apply(new_entries: list[dict], *, table_empty: bool) -> int:
    from core.state.session_scope import session_scope
    from models.catalog_design import SOURCE_IMPORT, SOURCE_SEED
    from modules.catalog import catalog_repository as catalog_repo

    source = SOURCE_SEED if table_empty else SOURCE_IMPORT
    inserted = 0
    with session_scope() as session:
        for entry in new_entries:
            before = catalog_repo.get_by_id(
                session, str(entry["design"].get("internalId") or "")
            )
            row = catalog_repo.upsert_design(
                session,
                design=entry["design"],
                series_key=entry["series_key"],
                source=source,
                catalog_version=entry.get("catalog_version"),
                overwrite=False,
            )
            if row is not None and before is None:
                inserted += 1
    return inserted


def _prompt_import(*, new_count: int, table_empty: bool) -> bool:
    source = "seed" if table_empty else "import"
    print()
    print(f"Import {new_count} design(s) into catalog_designs (source={source})?")
    raw = input("Import now? [y/N]: ").strip().lower()
    return raw in {"y", "yes", "1"}


def main() -> None:
    _require_wfrun()
    _ensure_python_bin_on_path()
    mode = os.environ.get("WFRUN_MODE", "")
    parser = argparse.ArgumentParser(
        description="Scan/import catalog theme JSON into catalog_designs"
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Import without prompting (non-interactive)",
    )
    args = parser.parse_args()

    print(f"📚 wfrun ({mode}): catalog designs scan/import")
    new_entries, new_count, authored_total, table_empty = _scan()
    print(f"Authored designs in JSON: {authored_total}")
    print(f"New additions (not in DB): {new_count}")
    if table_empty:
        print("catalog_designs is empty — first import will use source=seed")
    if new_count:
        print("— New internalIds —")
        for entry in new_entries:
            iid = entry["design"].get("internalId")
            name = entry["design"].get("design") or ""
            print(f"  {iid}  ({name})")
    else:
        print("No new additions.")
        return

    if args.apply:
        do_import = True
    else:
        do_import = _prompt_import(new_count=new_count, table_empty=table_empty)

    if not do_import:
        print("Skipped import.")
        return

    inserted = _apply(new_entries, table_empty=table_empty)
    print(f"Inserted: {inserted}")


if __name__ == "__main__":
    main()
