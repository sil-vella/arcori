#!/usr/bin/env python3
# dash Rename wf_template branding (contents + paths) to a project name
"""
wfrun script: replace wf_template branding variants only
  WF_TEMPLATE / WfTemplate / WF Template / wf_template / wftemplate
in file contents and matching file/directory basenames.

Does NOT rename flutter_base*, dart_bkend_base*, or python_base* trees.
Does not copy a template or touch git.

Examples:
  wfrun   # → automation/local/rename_wf_template_branding.py
  # (after wfrun selects this script, optional args:)
  #   my_cool_app
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

SKIP_DIR_NAMES = {
    ".git",
    ".dart_tool",
    ".idea",
    "__pycache__",
    "node_modules",
    "build",
    ".venv",
    "venv",
    ".pytest_cache",
}

# Never rewrite this runner's contents or rename this file.
_SELF_SCRIPT = Path(__file__).resolve()


def _is_self_script(path: str | Path) -> bool:
    try:
        return Path(path).resolve() == _SELF_SCRIPT
    except OSError:
        return False


def require_wfrun_root() -> Path:
    root = os.environ.get("WFRUN_ROOT", "").strip()
    mode = os.environ.get("WFRUN_MODE", "").strip()
    if not root or not mode:
        print(
            "❌ Run via wfrun — this script expects WFRUN_ROOT and WFRUN_MODE.",
            file=sys.stderr,
        )
        sys.exit(1)
    path = Path(root).resolve()
    if not path.is_dir():
        print(f"❌ WFRUN_ROOT is not a directory: {path}", file=sys.stderr)
        sys.exit(1)
    return path


def derive_product_name_variants(proj_name: str) -> dict[str, str]:
    sanitized = proj_name.strip().replace(" ", "_")
    parts = [part for part in sanitized.split("_") if part]
    if not parts:
        parts = [sanitized] if sanitized else ["project"]

    snake = "_".join(part.lower() for part in parts)
    return {
        "env_prefix": snake.upper(),
        "snake": snake,
        "flat": "".join(part.lower() for part in parts),
        "kebab": "-".join(part.lower() for part in parts),
        "pascal": "".join(part[:1].upper() + part[1:] for part in parts),
        "title": " ".join(part[:1].upper() + part[1:].lower() for part in parts),
    }


def branding_replacements(variants: dict[str, str]) -> tuple[tuple[str, str], ...]:
    # Longest / most specific first.
    return (
        ("WF_TEMPLATE", variants["env_prefix"]),
        ("WfTemplate:", f"{variants['pascal']}:"),
        ("WfTemplate", variants["pascal"]),
        ("WF Template", variants["title"]),
        ("wf_template", variants["snake"]),
        ("wf-template", variants["kebab"]),
        ("wftemplate", variants["flat"]),
    )


def apply_branding_replacements(text: str, variants: dict[str, str]) -> str:
    for old, new in branding_replacements(variants):
        text = text.replace(old, new)
    return text


def text_has_template_branding(text: str) -> bool:
    return any(
        marker in text
        for marker in (
            "WF_TEMPLATE",
            "WfTemplate",
            "WF Template",
            "wf_template",
            "wf-template",
            "wftemplate",
        )
    )


def _prune_walk_dirs(dirnames: list[str]) -> None:
    dirnames[:] = [d for d in dirnames if d not in SKIP_DIR_NAMES]


def walk_files(target_dir: str):
    for root, dirs, files in os.walk(target_dir):
        _prune_walk_dirs(dirs)
        for filename in files:
            path = os.path.join(root, filename)
            if _is_self_script(path):
                continue
            yield path


def rename_tree_entries(target_dir: str, name_transform, label: str | None = None) -> int:
    entries = []
    for root, dirs, files in os.walk(target_dir, topdown=True):
        _prune_walk_dirs(dirs)
        for name in files:
            path = os.path.join(root, name)
            if _is_self_script(path):
                continue
            entries.append(path)
        for name in dirs:
            entries.append(os.path.join(root, name))
    entries.sort(key=lambda p: p.count(os.sep), reverse=True)

    renamed = 0
    for path in entries:
        if not os.path.exists(path):
            continue
        if _is_self_script(path):
            continue
        parent, name = os.path.split(path)
        new_name = name_transform(name)
        if not new_name or new_name == name:
            continue
        new_path = os.path.join(parent, new_name)
        if os.path.exists(new_path):
            print(f"Skip rename (target exists): {path} -> {new_path}")
            continue
        try:
            os.rename(path, new_path)
            renamed += 1
            print(f"Renamed: {name} -> {new_name}")
        except Exception as e:
            print(f"Could not rename {path} -> {new_path}: {e}")
    if label:
        print(f"{label}: renamed {renamed} path(s).")
    return renamed


def replace_wf_template_branding(target_dir: str, proj_name: str) -> None:
    variants = derive_product_name_variants(proj_name)
    print(
        "Branding replacements:",
        f"env={variants['env_prefix']}_*,",
        f"docker={variants['pascal']}_*,",
        f"snake={variants['snake']},",
        f"flat={variants['flat']},",
        f"display='{variants['title']}'",
    )
    print(
        "Leaving flutter_base* / dart_bkend_base* / python_base* directory names unchanged."
    )
    print(f"Skipping this script: {_SELF_SCRIPT.name}")

    for file_path in walk_files(target_dir):
        try:
            with open(file_path, "rb") as f:
                content = f.read()
            try:
                text = content.decode("utf-8")
            except UnicodeDecodeError:
                continue
            if not text_has_template_branding(text):
                continue
            text = apply_branding_replacements(text, variants)
            with open(file_path, "w", encoding="utf-8") as f:
                f.write(text)
        except Exception as e:
            print(f"Could not process file {file_path}: {e}")

    rename_tree_entries(
        target_dir,
        lambda name: apply_branding_replacements(name, variants),
        label="Branding path rename",
    )


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "wfrun: replace wf_template branding variants in this repo "
            "(contents + matching path basenames). Does not rename "
            "flutter_base* / dart_bkend_base* / python_base*."
        )
    )
    parser.add_argument(
        "project_name",
        nargs="?",
        help="Product name (spaces become underscores). Prompted if omitted.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    target = require_wfrun_root()

    proj_name = (args.project_name or "").strip()
    if not proj_name:
        proj_name = input("Enter project name: ").strip()
    if not proj_name:
        print("Project name cannot be empty.", file=sys.stderr)
        return 2

    proj_name = proj_name.replace(" ", "_")
    print(f"Applying wf_template branding renames in: {target}")
    print(f"Project name: {proj_name}")
    replace_wf_template_branding(str(target), proj_name)
    print("wf_template branding renames complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
