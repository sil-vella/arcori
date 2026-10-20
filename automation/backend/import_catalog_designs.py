#!/usr/bin/env python3
# dash Catalog: scan / import theme JSON → catalog_designs
"""Scan authored theme JSON for designs missing from Postgres; prompt to import.

Always lists new internalIds + total count, then asks whether to insert.
Pass --apply to skip the prompt (non-interactive).
Pass --overwrite to refresh existing non-echo rows from JSON (e.g. gameplay prefs).

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


def _scan(*, overwrite: bool) -> tuple[list[dict], int, int, bool]:
    """Return (entries_to_write, write_count, authored_total, table_empty).

    Without overwrite: only designs missing from DB.
    With overwrite: all authored designs (upsert refreshes non-echo rows).
    """
    from core.state.session_scope import session_scope
    from modules.catalog.catalog_authoring import iter_authored_designs
    from modules.catalog import catalog_repository as catalog_repo

    authored = iter_authored_designs()
    with session_scope() as session:
        existing = catalog_repo.all_internal_ids(session)
        table_empty = len(existing) == 0
        if overwrite:
            return authored, len(authored), len(authored), table_empty
        new_entries: list[dict] = []
        for entry in authored:
            design = entry["design"]
            iid = str(design.get("internalId") or "").strip()
            if not iid or iid in existing:
                continue
            new_entries.append(entry)
        return new_entries, len(new_entries), len(authored), table_empty


def _apply(
    entries: list[dict], *, table_empty: bool, overwrite: bool
) -> tuple[int, int]:
    from core.state.session_scope import session_scope
    from models.catalog_design import SOURCE_IMPORT, SOURCE_SEED
    from modules.catalog import catalog_repository as catalog_repo
    from modules.catalog.catalog_ids import ensure_gen001

    source = SOURCE_SEED if table_empty else SOURCE_IMPORT
    inserted = 0
    updated = 0
    with session_scope() as session:
        for entry in entries:
            iid = str(entry["design"].get("internalId") or "").strip()
            try:
                iid = ensure_gen001(iid) if iid else ""
            except ValueError:
                continue
            before = catalog_repo.get_by_id(session, iid) if iid else None
            row = catalog_repo.upsert_design(
                session,
                design=entry["design"],
                series_key=entry["series_key"],
                source=source,
                catalog_version=entry.get("catalog_version"),
                overwrite=overwrite,
            )
            if row is None:
                continue
            if before is None:
                inserted += 1
            elif overwrite:
                updated += 1
    return inserted, updated


def _prompt_import(*, write_count: int, table_empty: bool, overwrite: bool) -> bool:
    source = "seed" if table_empty else "import"
    action = "Overwrite/refresh" if overwrite else "Import"
    print()
    print(
        f"{action} {write_count} design(s) into catalog_designs "
        f"(source={source}, overwrite={overwrite})?"
    )
    raw = input(f"{action} now? [y/N]: ").strip().lower()
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
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Refresh existing non-echo rows from authored JSON",
    )
    args = parser.parse_args()

    print(f"📚 wfrun ({mode}): catalog designs scan/import")
    entries, write_count, authored_total, table_empty = _scan(
        overwrite=args.overwrite
    )
    print(f"Authored designs in JSON: {authored_total}")
    if args.overwrite:
        print(f"Overwrite candidates (all authored): {write_count}")
    else:
        print(f"New additions (not in DB): {write_count}")
    if table_empty:
        print("catalog_designs is empty — first import will use source=seed")
    if write_count and not args.overwrite:
        print("— New internalIds —")
        for entry in entries:
            iid = entry["design"].get("internalId")
            name = entry["design"].get("design") or ""
            print(f"  {iid}  ({name})")
    elif write_count == 0:
        print("Nothing to write.")
        return

    if args.apply:
        do_import = True
    else:
        do_import = _prompt_import(
            write_count=write_count,
            table_empty=table_empty,
            overwrite=args.overwrite,
        )

    if not do_import:
        print("Skipped import.")
        return

    inserted, updated = _apply(
        entries, table_empty=table_empty, overwrite=args.overwrite
    )
    print(f"Inserted: {inserted}")
    if args.overwrite:
        print(f"Updated: {updated}")


if __name__ == "__main__":
    main()
