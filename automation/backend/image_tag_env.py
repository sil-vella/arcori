#!/usr/bin/env python3
# dash Shared helpers for Docker image tag + LOGGING_SWITCH flip (not a wfrun runner)
"""Shared helpers for build_and_push_*_docker.py: versioned tags, .env upsert, logging flip."""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

REQUIRED_DEPLOY_KEYS = (
    "JWT_SECRET",
    "JWT_REFRESH_SECRET",
    "SERVICE_KEY",
    "POSTGRES_PASSWORD",
    "POSTGRES_APP_PASSWORD",
)

_ASSIGN_TRUE_PY = re.compile(r"^(\s*)(LOGGING_SWITCH\s*=\s*)True(\s*(?:#.*)?)$")


class Colors:
    RED = "\033[0;31m"
    GREEN = "\033[0;32m"
    YELLOW = "\033[1;33m"
    BLUE = "\033[0;34m"
    NC = "\033[0m"


def require_wfrun_prod() -> tuple[Path, Path]:
    """Return (repo_root, env_file). Exit unless WFRUN_MODE=prod."""
    root = (os.environ.get("WFRUN_ROOT") or "").strip()
    mode = (os.environ.get("WFRUN_MODE") or "").strip()
    env_file = (os.environ.get("WFRUN_ENV_FILE") or "").strip()
    if not root or not mode or not env_file:
        print(
            f"{Colors.RED}❌ Run via wfrun / dashup — expects WFRUN_ROOT, "
            f"WFRUN_MODE, WFRUN_ENV_FILE.{Colors.NC}",
            file=sys.stderr,
        )
        sys.exit(1)
    if mode != "prod":
        print(
            f"{Colors.RED}❌ Build/push requires WFRUN_MODE=prod "
            f"(got {mode!r}). Choose prod in wfrun/dashboard.{Colors.NC}",
            file=sys.stderr,
        )
        sys.exit(1)
    env_path = Path(env_file)
    if not env_path.is_file():
        print(f"{Colors.RED}❌ Env file not found: {env_path}{Colors.NC}", file=sys.stderr)
        sys.exit(1)
    return Path(root), env_path


def ensure_deploy_keys_in_environ() -> None:
    missing = [k for k in REQUIRED_DEPLOY_KEYS if not (os.environ.get(k) or "").strip()]
    if missing:
        print(
            f"{Colors.RED}❌ Missing or empty in exported env: "
            f"{', '.join(missing)}{Colors.NC}",
            file=sys.stderr,
        )
        sys.exit(1)
    print(
        f"{Colors.GREEN}SSOT OK:{Colors.NC} required deploy keys present in exported env "
        f"(runtime via VPS .env, not baked into image)"
    )


def upsert_env_key(env_path: Path, key: str, value: str, *, sync_environ: bool = True) -> None:
    """Replace KEY=... or append under a Docker image tags comment section.

    When [sync_environ] is true (default), also set ``os.environ[key]`` so a
    long-lived wfrun/dashboard session and any follow-on script in the same
    process see the new value (not a stale export from session start).
    """
    key = key.strip()
    value = value.strip()
    if not key or not value:
        raise ValueError("key and value must be non-empty")

    text = env_path.read_text(encoding="utf-8") if env_path.is_file() else ""
    lines = text.splitlines(keepends=True)
    new_line = f"{key}={value}\n"
    key_pattern = re.compile(rf"^{re.escape(key)}\s*=")

    out: list[str] = []
    replaced = False
    for line in lines:
        body = line.rstrip("\n\r")
        if key_pattern.match(body):
            out.append(new_line)
            replaced = True
        else:
            out.append(line)

    if not replaced:
        if out and not out[-1].endswith("\n"):
            out.append("\n")
        if out and not out[-1].endswith("\n\n"):
            out.append("\n")
        out.append("# Docker image tags (updated by build_and_push_* scripts)\n")
        out.append(new_line)

    env_path.write_text("".join(out), encoding="utf-8")
    if sync_environ:
        os.environ[key] = value


def git_short_sha(project_root: Path) -> str:
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            capture_output=True,
            text=True,
            cwd=str(project_root),
            check=False,
        )
        if result.returncode == 0:
            sha = (result.stdout or "").strip()
            if sha:
                return sha
    except OSError:
        pass
    return "unknown"


def resolve_versioned_image_tag(project_root: Path) -> str:
    """{APP_VERSION}-{git_sha} unless IMAGE_TAG is set explicitly."""
    explicit = (os.environ.get("IMAGE_TAG") or "").strip()
    if explicit:
        return explicit
    app_version = (os.environ.get("APP_VERSION") or "1.0.0").strip() or "1.0.0"
    return f"{app_version}-{git_short_sha(project_root)}"


def record_image_tag(env_path: Path, key: str, tag: str) -> None:
    upsert_env_key(env_path, key, tag, sync_environ=True)
    print(
        f"{Colors.GREEN}✓ Recorded {key} in {env_path.name} "
        f"+ process env:{Colors.NC} {tag}"
    )


def check_docker() -> bool:
    try:
        subprocess.run(
            ["docker", "info"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=True,
        )
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False


def confirm_build() -> bool:
    if sys.stdin.isatty():
        response = input("Proceed with build and push? (y/n): ").strip().lower()
        if response != "y":
            print(f"{Colors.YELLOW}Build cancelled.{Colors.NC}")
            return False
        return True
    print("Non-interactive mode: Auto-confirming build and push...")
    return True


def docker_platform() -> str:
    return (os.environ.get("DOCKER_PLATFORM") or "linux/amd64").strip() or "linux/amd64"


def docker_username() -> str:
    return (os.environ.get("DOCKER_USERNAME") or "silvella").strip() or "silvella"


# --- LOGGING_SWITCH flip / restore -------------------------------------------------

_logging_backups: dict[Path, str] = {}


def disable_python_logging_switches(build_context: Path) -> None:
    """Set LOGGING_SWITCH = False on lines that assign True (backup originals first)."""
    print(f"\n{Colors.BLUE}Setting LOGGING_SWITCH = False for Docker build...{Colors.NC}")
    modified_count = 0
    line_changes = 0

    for py_file in build_context.rglob("*.py"):
        parts = py_file.parts
        if "__pycache__" in parts:
            continue
        try:
            original = py_file.read_text(encoding="utf-8")
        except OSError as e:
            print(f"  {Colors.RED}✗{Colors.NC} Could not read {py_file}: {e}")
            continue

        lines = original.splitlines(keepends=True)
        new_lines: list[str] = []
        file_changed = False

        for line in lines:
            stripped_left = line.lstrip()
            if stripped_left.startswith("#"):
                new_lines.append(line)
                continue
            body = line.rstrip("\n\r")
            nl = line[len(body) :]
            m = _ASSIGN_TRUE_PY.match(body)
            if m:
                new_body = f"{m.group(1)}{m.group(2)}False{m.group(3)}"
                new_lines.append(new_body + nl)
                file_changed = True
                line_changes += 1
            else:
                new_lines.append(line)

        if not file_changed:
            continue

        _logging_backups[py_file] = original
        try:
            py_file.write_text("".join(new_lines), encoding="utf-8")
        except OSError as e:
            print(f"  {Colors.RED}✗{Colors.NC} Could not write {py_file}: {e}")
            del _logging_backups[py_file]
            continue

        modified_count += 1
        rel = py_file.relative_to(build_context)
        print(f"  {Colors.GREEN}✓{Colors.NC} {rel}")

    if modified_count == 0:
        print(
            f"{Colors.YELLOW}No LOGGING_SWITCH = True assignments found "
            f"(already False).{Colors.NC}"
        )
    else:
        print(
            f"{Colors.GREEN}✓ Updated LOGGING_SWITCH in {modified_count} file(s) "
            f"({line_changes} line(s)){Colors.NC}"
        )


def disable_dart_logging_switches(build_context: Path) -> None:
    """Force LOGGING_SWITCH = false in Dart sources under build context."""
    print(f"\n{Colors.BLUE}Disabling LOGGING_SWITCH in Dart sources...{Colors.NC}")
    replaced_files = 0
    replaced_occurrences = 0

    for dart_file in build_context.rglob("*.dart"):
        try:
            text = dart_file.read_text(encoding="utf-8")
            original = text
            new_text = text.replace("LOGGING_SWITCH = true", "LOGGING_SWITCH = false")
            new_text = new_text.replace(
                "const bool LOGGING_SWITCH = true",
                "const bool LOGGING_SWITCH = false",
            )
            new_text = new_text.replace(
                "static const bool LOGGING_SWITCH = true",
                "static const bool LOGGING_SWITCH = false",
            )
            if new_text == original:
                continue
            if dart_file not in _logging_backups:
                _logging_backups[dart_file] = original
            dart_file.write_text(new_text, encoding="utf-8")
            occurrences = (
                original.count("LOGGING_SWITCH = true")
                + original.count("const bool LOGGING_SWITCH = true")
                + original.count("static const bool LOGGING_SWITCH = true")
            )
            replaced_occurrences += occurrences
            replaced_files += 1
            rel = dart_file.relative_to(build_context)
            print(f"  {Colors.GREEN}✓{Colors.NC} Updated {rel} ({occurrences} occurrence(s))")
        except OSError as e:
            rel = dart_file.relative_to(build_context)
            print(f"  {Colors.RED}✗{Colors.NC} Error processing {rel}: {e}")

    if replaced_files == 0:
        print(
            f"{Colors.YELLOW}No LOGGING_SWITCH = true found in Dart sources "
            f"(already disabled or not present).{Colors.NC}"
        )
    else:
        print(
            f"{Colors.GREEN}✓ Disabled LOGGING_SWITCH in {replaced_occurrences} "
            f"place(s) across {replaced_files} file(s){Colors.NC}"
        )


def restore_logging_switches(build_context: Path | None = None) -> None:
    """Restore sources from backup after build."""
    if not _logging_backups:
        return

    print(f"\n{Colors.BLUE}Restoring LOGGING_SWITCH assignments...{Colors.NC}")
    for path, original in list(_logging_backups.items()):
        try:
            path.write_text(original, encoding="utf-8")
            if build_context is not None:
                try:
                    rel = path.relative_to(build_context)
                except ValueError:
                    rel = path
            else:
                rel = path
            print(f"  {Colors.GREEN}✓{Colors.NC} {rel}")
        except OSError as e:
            print(f"  {Colors.RED}✗{Colors.NC} Could not restore {path}: {e}")

    _logging_backups.clear()
    print(f"{Colors.GREEN}✓ Restore complete{Colors.NC}")
