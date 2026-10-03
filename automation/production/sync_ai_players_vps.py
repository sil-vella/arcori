#!/usr/bin/env python3
# dash Sync local AI players (+ Kin Lotties) to VPS DB
"""Replace AI players on the VPS with the local AI set (DB rows + Kin media).

Requires wfrun/dashboard with WFRUN_MODE=prod.

Scope (strict):
  - DELETE on VPS only users matching AI identity
    (email *@arcoriaiplayer.app OR avari_profiles.notes = ai_seed:v1)
  - INSERT only those users' cascaded game rows from the local source DB
  - Copy only Kin media stems for those AI genesis_design_ids
  - Does NOT touch human users, catalog seeds, compose, nginx, or other tables

Source DB: AI_SYNC_SOURCE_DATABASE_URL, or MIGRATION_DATABASE_URL / DATABASE_URL
from repo .env.local (never use .env.prod DB URL as source — that is VPS-shaped).

Local Kin media: .tmp/ai_feed_uploads, else Docker volume
arcori_fastapi_dart_flutter_arcori_uploads.

Target: SSH → VPS Arcori_postgres (DELETE+COPY) + Docker install into
APP_ROOT/data/uploads/kin/{players,designs} (API-owned mount; not host rsync).
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path
from urllib.parse import unquote, urlparse

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR.parent / "backend"))
sys.path.insert(0, str(SCRIPT_DIR.parent.parent / "app_codebase" / "python_base_05" / "bin"))

from image_tag_env import Colors, require_wfrun_prod  # noqa: E402

AI_EMAIL_DOMAIN = "arcoriaiplayer.app"
AI_SEED_MARKER = "ai_seed:v1"
LOCAL_PG_CONTAINER = "Arcori_postgres"
LOCAL_UPLOADS_VOLUME = "arcori_fastapi_dart_flutter_arcori_uploads"
REMOTE_BUNDLE_DIR = "/tmp/arcori_ai_players_sync"

# Tables copied for AI user_ids only (users first; children after DELETE CASCADE).
AI_TABLES: tuple[tuple[str, str], ...] = (
    (
        "users",
        "id,username,email,password_hash,is_guest,created_at,updated_at,"
        "avatar_url,email_verified_at",
    ),
    (
        "avari_profiles",
        "id,user_id,display_name,primary_title,titles,rank_xp,rank_level,rank_label,"
        "gold_fragments,gold_arcori,matches_played,wins,flips,win_streak_current,"
        "win_streak_best,onboarding_completed,onboarding_kin_chosen,"
        "onboarding_genesis_created,onboarding_starter_granted,"
        "onboarding_guided_practice_done,onboarding_intros_done,daily_login_streak,"
        "daily_last_login_reward_at,daily_cache_claimed_at,daily_no_miss_streak,"
        "notifications_push,notes,created_at,updated_at",
    ),
    (
        "player_kin",
        "id,user_id,subtheme,style,finish,effect,genesis_design_id,chosen_name,"
        "customization,created_at,updated_at,catalog_design",
    ),
    (
        "player_design_access",
        "id,user_id,design_id,source,created_at",
    ),
    (
        "player_mastery",
        "id,user_id,design_id,generation_number,points,created_at,updated_at",
    ),
    (
        "player_slammers",
        "id,user_id,design_id,permanent,charges_remaining,source,created_at",
    ),
)

REQUIRED_VPS_KEYS = ("VPS_SSH_HOST", "VPS_SSH_USER", "VPS_SSH_KEY")


def _env(key: str, default: str = "") -> str:
    return (os.environ.get(key) or default).strip()


def _env_from_file(key: str, env_path: Path) -> str:
    if not env_path.is_file():
        return ""
    for raw in env_path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export ") :].lstrip()
        if not line.startswith(f"{key}="):
            continue
        val = line.split("=", 1)[1].strip()
        if len(val) >= 2 and val[0] == val[-1] and val[0] in "\"'":
            val = val[1:-1]
        return val.strip()
    return ""


def _require_vps_keys() -> None:
    missing = [k for k in REQUIRED_VPS_KEYS if not _env(k)]
    if missing:
        print(
            f"{Colors.RED}❌ Missing or empty in exported env: "
            f"{', '.join(missing)}{Colors.NC}",
            file=sys.stderr,
        )
        sys.exit(1)


def _ssh_base() -> list[str]:
    key = _env("VPS_SSH_KEY")
    key_path = Path(key).expanduser()
    if not key_path.is_file():
        print(f"{Colors.RED}❌ SSH key not found: {key_path}{Colors.NC}", file=sys.stderr)
        sys.exit(1)
    return [
        "ssh",
        "-i",
        str(key_path),
        "-o",
        "StrictHostKeyChecking=accept-new",
        "-o",
        "BatchMode=yes",
    ]


def _ssh_target() -> str:
    return f"{_env('VPS_SSH_USER')}@{_env('VPS_SSH_HOST')}"


def _run(
    cmd: list[str],
    *,
    check: bool = True,
    capture: bool = False,
) -> subprocess.CompletedProcess[str]:
    print(f"  $ {' '.join(cmd)}")
    return subprocess.run(cmd, check=check, text=True, capture_output=capture)


def _ssh(
    remote_cmd: str,
    *,
    check: bool = True,
    capture: bool = False,
) -> subprocess.CompletedProcess[str]:
    return _run(_ssh_base() + [_ssh_target(), remote_cmd], check=check, capture=capture)


def _docker_wrap(app_user: str, inner: str) -> str:
    if app_user == "root":
        return inner
    escaped = inner.replace("'", "'\"'\"'")
    return f"sg docker -c '{escaped}'"


def _scp(local: Path, remote_path: str) -> None:
    key = str(Path(_env("VPS_SSH_KEY")).expanduser())
    _run(
        [
            "scp",
            "-i",
            key,
            "-o",
            "StrictHostKeyChecking=accept-new",
            "-o",
            "BatchMode=yes",
            str(local),
            f"{_ssh_target()}:{remote_path}",
        ]
    )


def _uploads_uid_gid() -> tuple[str, str]:
    """API container write identity for host-mounted uploads (see .env.prod VPS_APP_*)."""
    uid = _env("VPS_APP_UID") or "1000"
    gid = _env("VPS_APP_GID") or "1000"
    return uid, gid


def _vps_install_kin_media(
    app_user: str,
    app_root: str,
    media_root: Path,
    *,
    expected_players: int,
    expected_designs: int,
) -> None:
    """Install Kin players/designs into VPS uploads via Docker (host rsync lacks write)."""
    players = media_root / "kin" / "players"
    designs = media_root / "kin" / "designs"
    if not players.is_dir() and not designs.is_dir():
        return

    with tempfile.TemporaryDirectory(prefix="arcori_ai_media_") as tmp:
        tar_path = Path(tmp) / "ai_kin_media.tgz"
        with tarfile.open(tar_path, "w:gz") as tf:
            if players.is_dir():
                for path in sorted(players.glob("*.json")):
                    tf.add(path, arcname=f"kin/players/{path.name}")
            if designs.is_dir():
                for path in sorted(designs.glob("*.json")):
                    tf.add(path, arcname=f"kin/designs/{path.name}")
        remote_tar = f"{REMOTE_BUNDLE_DIR}_media.tgz"
        _scp(tar_path, remote_tar)

    uid, gid = _uploads_uid_gid()
    uploads = f"{app_root}/data/uploads"
    # Avoid $(...) in double quotes — outer sg/ssh shells expand them early.
    # Alpine script uses single quotes; \$ never needed if we use wc -l on find.
    alpine = (
        "mkdir -p /data/uploads/kin/players /data/uploads/kin/designs && "
        "tar -xzf /src/media.tgz -C /data/uploads && "
        f"chown -R {uid}:{gid} /data/uploads/kin/players /data/uploads/kin/designs && "
        "p=$(find /data/uploads/kin/players -type f -name '*.json' | wc -l) && "
        "d=$(find /data/uploads/kin/designs -type f -name '*.json' | wc -l) && "
        "echo players=$p designs=$d && "
        f'test "$p" -ge {int(expected_players)} && '
        f'test "$d" -ge {int(expected_designs)}'
    )
    # Escape for: sg docker -c '... docker run ... sh -c '\''ALPINE'\'' ...'
    alpine_q = alpine.replace("'", "'\"'\"'")
    inner = (
        f"mkdir -p {uploads}/kin/players {uploads}/kin/designs && "
        f"docker run --rm "
        f"-v {uploads}:/data/uploads "
        f"-v {remote_tar}:/src/media.tgz:ro "
        f"alpine sh -c '{alpine_q}' && "
        f"rm -f {remote_tar}"
    )
    result = _ssh(
        f"set -a && . {app_root}/.env && set +a && " + _docker_wrap(app_user, inner),
        check=False,
        capture=True,
    )
    out = ((result.stdout or "") + (result.stderr or "")).strip()
    if out:
        print(out)
    if result.returncode != 0:
        print(
            f"{Colors.RED}❌ Kin media install failed or count below expected "
            f"(players>={expected_players}, designs>={expected_designs}){Colors.NC}",
            file=sys.stderr,
        )
        sys.exit(1)


def _resolve_source_database_url(repo_root: Path, env_path: Path) -> str:
    """Local AI source — never treat .env.prod DB URL as source."""
    explicit = _env("AI_SYNC_SOURCE_DATABASE_URL") or _env_from_file(
        "AI_SYNC_SOURCE_DATABASE_URL", env_path
    )
    if explicit:
        return explicit

    local_env = repo_root / ".env.local"
    for key in ("MIGRATION_DATABASE_URL", "DATABASE_URL"):
        val = _env_from_file(key, local_env)
        if val:
            print(
                f"{Colors.YELLOW}⚠ AI_SYNC_SOURCE_DATABASE_URL unset — "
                f"using {key} from .env.local{Colors.NC}"
            )
            return val

    print(
        f"{Colors.RED}❌ Set AI_SYNC_SOURCE_DATABASE_URL (local AI DB), "
        f"or ensure .env.local has MIGRATION_DATABASE_URL.{Colors.NC}",
        file=sys.stderr,
    )
    sys.exit(1)


def _parse_pg_url(url: str) -> dict[str, str]:
    parsed = urlparse(url)
    if parsed.scheme not in {"postgresql", "postgres"}:
        print(
            f"{Colors.RED}❌ Unsupported DB URL scheme: {parsed.scheme!r}{Colors.NC}",
            file=sys.stderr,
        )
        sys.exit(1)
    db = (parsed.path or "").lstrip("/")
    if not db:
        print(f"{Colors.RED}❌ DATABASE_URL missing database name{Colors.NC}", file=sys.stderr)
        sys.exit(1)
    return {
        "user": unquote(parsed.username or ""),
        "password": unquote(parsed.password or ""),
        "host": parsed.hostname or "127.0.0.1",
        "port": str(parsed.port or 5432),
        "dbname": db,
    }


def _local_container_running() -> bool:
    result = subprocess.run(
        ["docker", "inspect", "-f", "{{.State.Running}}", LOCAL_PG_CONTAINER],
        check=False,
        text=True,
        capture_output=True,
    )
    return result.returncode == 0 and (result.stdout or "").strip() == "true"


def _psql_local(source_url: str, sql: str) -> str:
    """Run SQL against the local source DB (docker exec preferred)."""
    creds = _parse_pg_url(source_url)
    if _local_container_running():
        result = subprocess.run(
            [
                "docker",
                "exec",
                "-e",
                f"PGPASSWORD={creds['password']}",
                LOCAL_PG_CONTAINER,
                "psql",
                "-U",
                creds["user"] or "arcori",
                "-d",
                creds["dbname"],
                "-v",
                "ON_ERROR_STOP=1",
                "-t",
                "-A",
                "-c",
                sql,
            ],
            check=True,
            text=True,
            capture_output=True,
        )
        return result.stdout or ""

    env = os.environ.copy()
    env["PGPASSWORD"] = creds["password"]
    result = subprocess.run(
        [
            "psql",
            "-h",
            creds["host"],
            "-p",
            creds["port"],
            "-U",
            creds["user"] or "arcori",
            "-d",
            creds["dbname"],
            "-v",
            "ON_ERROR_STOP=1",
            "-t",
            "-A",
            "-c",
            sql,
        ],
        check=True,
        text=True,
        capture_output=True,
        env=env,
    )
    return result.stdout or ""


def _copy_out_local(source_url: str, select_sql: str) -> str:
    """COPY (query) TO STDOUT CSV HEADER via local postgres."""
    wrapped = f"COPY ({select_sql}) TO STDOUT WITH (FORMAT csv, HEADER true)"
    creds = _parse_pg_url(source_url)
    if _local_container_running():
        result = subprocess.run(
            [
                "docker",
                "exec",
                "-e",
                f"PGPASSWORD={creds['password']}",
                LOCAL_PG_CONTAINER,
                "psql",
                "-U",
                creds["user"] or "arcori",
                "-d",
                creds["dbname"],
                "-v",
                "ON_ERROR_STOP=1",
                "-c",
                wrapped,
            ],
            check=True,
            text=True,
            capture_output=True,
        )
        return result.stdout or ""

    env = os.environ.copy()
    env["PGPASSWORD"] = creds["password"]
    result = subprocess.run(
        [
            "psql",
            "-h",
            creds["host"],
            "-p",
            creds["port"],
            "-U",
            creds["user"] or "arcori",
            "-d",
            creds["dbname"],
            "-v",
            "ON_ERROR_STOP=1",
            "-c",
            wrapped,
        ],
        check=True,
        text=True,
        capture_output=True,
        env=env,
    )
    return result.stdout or ""


def _ai_user_filter_sql() -> str:
    return (
        f"lower(u.email) LIKE '%@{AI_EMAIL_DOMAIN}' OR EXISTS ("
        "SELECT 1 FROM avari_profiles a "
        f"WHERE a.user_id = u.id AND a.notes = '{AI_SEED_MARKER}')"
    )


def _count_csv_rows(csv_text: str) -> int:
    if not csv_text.strip():
        return 0
    reader = csv.reader(io.StringIO(csv_text))
    rows = list(reader)
    return max(0, len(rows) - 1)


def _art_basename(internal_id: str) -> str:
    from modules.catalog.catalog_ids import art_basename

    return art_basename(internal_id) or (internal_id or "").strip()


def _collect_media_stems(source_url: str) -> list[str]:
    sql = (
        "SELECT pk.genesis_design_id FROM player_kin pk "
        "JOIN users u ON u.id = pk.user_id "
        f"WHERE {_ai_user_filter_sql()}"
    )
    out = _psql_local(source_url, sql)
    stems: list[str] = []
    seen: set[str] = set()
    for line in out.splitlines():
        raw = line.strip()
        if not raw:
            continue
        stem = _art_basename(raw)
        if stem and stem not in seen:
            seen.add(stem)
            stems.append(stem)
    return stems


def _staging_complete(staging: Path, stems: list[str]) -> bool:
    if not stems:
        return False
    return all(
        (staging / "kin" / "players" / f"{s}.json").is_file()
        and (staging / "kin" / "designs" / f"{s}.json").is_file()
        for s in stems
    )


def _find_local_media_root(repo_root: Path, stems: list[str]) -> Path | None:
    staging = repo_root / ".tmp" / "ai_feed_uploads"
    if _staging_complete(staging, stems):
        return staging

    extract = repo_root / ".tmp" / "ai_sync_uploads_extract"
    if extract.exists():
        shutil.rmtree(extract)
    (extract / "kin" / "players").mkdir(parents=True)
    (extract / "kin" / "designs").mkdir(parents=True)

    list_result = subprocess.run(
        [
            "docker",
            "run",
            "--rm",
            "-v",
            f"{LOCAL_UPLOADS_VOLUME}:/data/uploads:ro",
            "alpine",
            "sh",
            "-c",
            "ls /data/uploads/kin/players 2>/dev/null; echo ---; "
            "ls /data/uploads/kin/designs 2>/dev/null",
        ],
        check=False,
        text=True,
        capture_output=True,
    )
    if list_result.returncode != 0:
        return None

    available = set((list_result.stdout or "").split())
    wanted = [f"{s}.json" for s in stems if f"{s}.json" in available]
    if not wanted:
        return None

    # Write file list into archive via docker + host path mount.
    list_file = extract / "_want.txt"
    list_file.write_text("\n".join(wanted) + "\n", encoding="utf-8")
    tar_result = subprocess.run(
        [
            "docker",
            "run",
            "--rm",
            "-v",
            f"{LOCAL_UPLOADS_VOLUME}:/data/uploads:ro",
            "-v",
            f"{extract}:/out",
            "alpine",
            "sh",
            "-c",
            (
                "cd /data/uploads && "
                "while IFS= read -r f; do "
                "  [ -f kin/players/$f ] && echo kin/players/$f; "
                "  [ -f kin/designs/$f ] && echo kin/designs/$f; "
                "done < /out/_want.txt | tar -cf /out/_pull.tar -T -"
            ),
        ],
        check=False,
        text=True,
        capture_output=True,
    )
    tar_path = extract / "_pull.tar"
    if tar_result.returncode != 0 or not tar_path.is_file():
        return None
    with tarfile.open(tar_path, "r") as tf:
        tf.extractall(extract)
    tar_path.unlink(missing_ok=True)
    list_file.unlink(missing_ok=True)
    if not _staging_complete(extract, stems):
        missing = [
            s
            for s in stems
            if not (extract / "kin" / "players" / f"{s}.json").is_file()
            or not (extract / "kin" / "designs" / f"{s}.json").is_file()
        ]
        print(
            f"{Colors.YELLOW}⚠ Volume incomplete for {len(missing)} stems "
            f"(example {missing[0] if missing else ''}){Colors.NC}"
        )
        return None
    return extract


def _stage_media(bundle: Path, media_root: Path, stems: list[str]) -> tuple[int, int]:
    players_dst = bundle / "media" / "kin" / "players"
    designs_dst = bundle / "media" / "kin" / "designs"
    players_dst.mkdir(parents=True, exist_ok=True)
    designs_dst.mkdir(parents=True, exist_ok=True)
    p_n = d_n = 0
    missing: list[str] = []
    for stem in stems:
        src_p = media_root / "kin" / "players" / f"{stem}.json"
        src_d = media_root / "kin" / "designs" / f"{stem}.json"
        if src_p.is_file():
            shutil.copy2(src_p, players_dst / f"{stem}.json")
            p_n += 1
        else:
            missing.append(f"players/{stem}.json")
        if src_d.is_file():
            shutil.copy2(src_d, designs_dst / f"{stem}.json")
            d_n += 1
        else:
            missing.append(f"designs/{stem}.json")
    if missing:
        print(
            f"{Colors.RED}❌ Missing {len(missing)} Kin media files "
            f"(first: {missing[0]}){Colors.NC}",
            file=sys.stderr,
        )
        sys.exit(1)
    return p_n, d_n


def _export_tables(source_url: str, bundle: Path) -> dict[str, int]:
    counts: dict[str, int] = {}
    filt = _ai_user_filter_sql()
    for table, cols in AI_TABLES:
        if table == "users":
            select = f"SELECT {cols} FROM users u WHERE {filt}"
        else:
            select = (
                f"SELECT {cols} FROM {table} t "
                f"WHERE t.user_id IN (SELECT u.id FROM users u WHERE {filt})"
            )
        csv_text = _copy_out_local(source_url, select)
        (bundle / f"{table}.csv").write_text(csv_text, encoding="utf-8")
        counts[table] = _count_csv_rows(csv_text)
    return counts


def _write_apply_sql(bundle: Path) -> None:
    """VPS-side SQL: delete AI users only, then COPY AI CSVs."""
    lines: list[str] = [
        "-- AI players only — generated by sync_ai_players_vps.py",
        "BEGIN;",
        "",
        "-- 1) Remove existing AI players (CASCADE child rows). Humans untouched.",
        "DELETE FROM users u",
        f"WHERE lower(u.email) LIKE '%@{AI_EMAIL_DOMAIN}'",
        "   OR EXISTS (",
        "        SELECT 1 FROM avari_profiles a",
        "        WHERE a.user_id = u.id AND a.notes = "
        f"'{AI_SEED_MARKER}'",
        "   );",
        "",
    ]
    for table, cols in AI_TABLES:
        lines.append(
            f"\\copy {table} ({cols}) FROM '{REMOTE_BUNDLE_DIR}/{table}.csv' "
            "WITH (FORMAT csv, HEADER true)"
        )
    lines.extend(["", "COMMIT;", ""])
    (bundle / "apply.psql").write_text("\n".join(lines), encoding="utf-8")


def _vps_list_ai_stems(app_user: str, app_root: str) -> list[str]:
    inner = (
        "docker exec -e PGPASSWORD=\"$POSTGRES_PASSWORD\" Arcori_postgres "
        "psql -U \"$POSTGRES_USER\" -d \"$POSTGRES_DB\" -t -A -c "
        "\"SELECT pk.genesis_design_id FROM player_kin pk "
        "JOIN users u ON u.id = pk.user_id "
        f"WHERE lower(u.email) LIKE '%@{AI_EMAIL_DOMAIN}' "
        "OR EXISTS (SELECT 1 FROM avari_profiles a "
        f"WHERE a.user_id = u.id AND a.notes = '{AI_SEED_MARKER}');\""
    )
    remote = f"set -a && . {app_root}/.env && set +a && " + _docker_wrap(app_user, inner)
    result = _ssh(remote, check=False, capture=True)
    if result.returncode != 0:
        print(
            f"{Colors.YELLOW}⚠ Could not list existing VPS AI stems "
            f"(continuing): {(result.stderr or result.stdout or '').strip()}{Colors.NC}"
        )
        return []
    stems: list[str] = []
    seen: set[str] = set()
    for line in (result.stdout or "").splitlines():
        raw = line.strip()
        if not raw:
            continue
        stem = _art_basename(raw)
        if stem and stem not in seen:
            seen.add(stem)
            stems.append(stem)
    return stems


def _vps_remove_media_stems(app_user: str, app_root: str, stems: list[str]) -> None:
    """Delete obsolete AI Kin files via Docker (uploads not writable by SSH user)."""
    if not stems:
        return
    uploads = f"{app_root}/data/uploads"
    chunk_size = 80
    for i in range(0, len(stems), chunk_size):
        chunk = stems[i : i + chunk_size]
        # Stems are art_basename tokens (no spaces/quotes).
        listed = " ".join(chunk)
        inner = (
            f"docker run --rm -v {uploads}:/data/uploads alpine sh -c "
            f"\"for s in {listed}; do "
            f"rm -f /data/uploads/kin/players/\\$s.json "
            f"/data/uploads/kin/designs/\\$s.json; "
            f"done; echo removed={len(chunk)}\""
        )
        _ssh(
            f"set -a && . {app_root}/.env && set +a && "
            + _docker_wrap(app_user, inner),
            check=False,
        )


def _vps_apply_db(app_user: str, app_root: str, tarball: Path) -> None:
    remote_tar = f"{REMOTE_BUNDLE_DIR}.tgz"
    _scp(tarball, remote_tar)
    inner = (
        f"rm -rf {REMOTE_BUNDLE_DIR} && mkdir -p {REMOTE_BUNDLE_DIR} && "
        f"tar -xzf {remote_tar} -C {REMOTE_BUNDLE_DIR} && "
        f"docker exec Arcori_postgres mkdir -p {REMOTE_BUNDLE_DIR} && "
        f"docker cp {REMOTE_BUNDLE_DIR}/. Arcori_postgres:{REMOTE_BUNDLE_DIR}/ && "
        "docker exec -e PGPASSWORD=\"$POSTGRES_PASSWORD\" Arcori_postgres "
        "psql -U \"$POSTGRES_USER\" -d \"$POSTGRES_DB\" "
        f"-v ON_ERROR_STOP=1 -f {REMOTE_BUNDLE_DIR}/apply.psql && "
        f"docker exec Arcori_postgres rm -rf {REMOTE_BUNDLE_DIR} && "
        f"rm -rf {REMOTE_BUNDLE_DIR} {remote_tar}"
    )
    remote = f"set -a && . {app_root}/.env && set +a && " + _docker_wrap(app_user, inner)
    _ssh(remote, check=True)


def _vps_verify(app_user: str, app_root: str, expected_users: int) -> None:
    inner = (
        "docker exec -e PGPASSWORD=\"$POSTGRES_PASSWORD\" Arcori_postgres "
        "psql -U \"$POSTGRES_USER\" -d \"$POSTGRES_DB\" -t -A -c "
        "\"SELECT COUNT(*) FROM users u "
        f"WHERE lower(u.email) LIKE '%@{AI_EMAIL_DOMAIN}' "
        "OR EXISTS (SELECT 1 FROM avari_profiles a "
        f"WHERE a.user_id = u.id AND a.notes = '{AI_SEED_MARKER}');\""
    )
    remote = f"set -a && . {app_root}/.env && set +a && " + _docker_wrap(app_user, inner)
    result = _ssh(remote, check=True, capture=True)
    got = (result.stdout or "").strip().splitlines()
    count_s = got[-1].strip() if got else ""
    try:
        count = int(count_s)
    except ValueError:
        count = -1
    if count != expected_users:
        print(
            f"{Colors.RED}❌ VPS AI user count={count} expected={expected_users}{Colors.NC}",
            file=sys.stderr,
        )
        sys.exit(1)
    print(f"{Colors.GREEN}✓ VPS AI users: {count}{Colors.NC}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Sync local AI players (+ Kin Lotties) to VPS — AI rows only."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Export + validate locally; do not write to VPS",
    )
    parser.add_argument(
        "--yes",
        action="store_true",
        help="Skip interactive confirm",
    )
    args = parser.parse_args()

    repo_root, env_path = require_wfrun_prod()
    _require_vps_keys()
    source_url = _resolve_source_database_url(repo_root, env_path)
    app_root = (
        _env("APP_ROOT") or _env_from_file("APP_ROOT", env_path) or "/opt/apps/arcori"
    )
    app_user = _env("VPS_SSH_USER")

    print(f"{Colors.BLUE}AI → VPS sync (AI players only){Colors.NC}")
    print(
        f"  source:    {urlparse(source_url).hostname}:"
        f"{urlparse(source_url).port or 5432}"
    )
    print(f"  VPS:       {_ssh_target()}")
    print(f"  APP_ROOT:  {app_root}")
    print(f"  identity:  *@{AI_EMAIL_DOMAIN} OR notes={AI_SEED_MARKER}")

    with tempfile.TemporaryDirectory(prefix="arcori_ai_sync_") as tmp:
        bundle = Path(tmp) / "bundle"
        bundle.mkdir(parents=True)

        print(f"\n{Colors.BLUE}Exporting AI rows from local DB...{Colors.NC}")
        counts = _export_tables(source_url, bundle)
        for table, n in counts.items():
            print(f"  {table}: {n}")

        user_count = counts.get("users", 0)
        if user_count <= 0:
            print(f"{Colors.RED}❌ No AI users in source DB{Colors.NC}", file=sys.stderr)
            return 1
        if counts.get("player_kin", 0) != user_count:
            print(
                f"{Colors.YELLOW}⚠ player_kin={counts.get('player_kin')} "
                f"users={user_count}{Colors.NC}"
            )

        stems = _collect_media_stems(source_url)
        print(f"  kin media stems: {len(stems)}")

        media_root = _find_local_media_root(repo_root, stems)
        if media_root is None:
            print(
                f"{Colors.RED}❌ Could not locate local Kin media for AI stems. "
                f"Run feed_ai_players first (writes .tmp/ai_feed_uploads)."
                f"{Colors.NC}",
                file=sys.stderr,
            )
            return 1
        print(f"  media root: {media_root}")
        p_n, d_n = _stage_media(bundle, media_root, stems)
        print(f"  staged players={p_n} designs={d_n}")

        (bundle / "meta.json").write_text(
            json.dumps(
                {
                    "email_domain": AI_EMAIL_DOMAIN,
                    "seed_marker": AI_SEED_MARKER,
                    "counts": counts,
                    "stems": stems,
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        _write_apply_sql(bundle)

        print()
        print(
            f"{Colors.YELLOW}This will DELETE all AI players on the VPS DB "
            f"and replace them with {user_count} local AI players "
            f"(+ their Kin Lottie/design files only).{Colors.NC}"
        )
        print("Human users and non-AI data are not modified.")
        if args.dry_run:
            print(f"{Colors.GREEN}✓ Dry-run OK — no VPS changes{Colors.NC}")
            return 0
        if not args.yes:
            if sys.stdin.isatty():
                response = input(
                    "Proceed with VPS AI player sync? (y/n): "
                ).strip().lower()
                if response != "y":
                    print(f"{Colors.YELLOW}Cancelled.{Colors.NC}")
                    return 0
            else:
                print("Non-interactive mode: Auto-confirming AI sync...")

        db_dir = Path(tmp) / "db_only"
        db_dir.mkdir()
        for name in ("apply.psql", "meta.json", *[f"{t}.csv" for t, _ in AI_TABLES]):
            shutil.copy2(bundle / name, db_dir / name)
        tarball = Path(tmp) / "ai_players_db.tgz"
        with tarfile.open(tarball, "w:gz") as tf:
            for path in db_dir.iterdir():
                tf.add(path, arcname=path.name)

        print(f"\n{Colors.BLUE}Listing existing VPS AI media stems...{Colors.NC}")
        old_stems = _vps_list_ai_stems(app_user, app_root)
        print(f"  existing VPS AI stems: {len(old_stems)}")

        print(f"\n{Colors.BLUE}Applying AI-only DB replace on VPS...{Colors.NC}")
        _vps_apply_db(app_user, app_root, tarball)

        obsolete = sorted(set(old_stems) - set(stems))
        if obsolete:
            print(
                f"\n{Colors.BLUE}Removing {len(obsolete)} obsolete AI media "
                f"stems on VPS...{Colors.NC}"
            )
            _vps_remove_media_stems(app_user, app_root, obsolete)

        print(f"\n{Colors.BLUE}Installing AI Kin media into VPS uploads...{Colors.NC}")
        _vps_install_kin_media(
            app_user,
            app_root,
            bundle / "media",
            expected_players=p_n,
            expected_designs=d_n,
        )

        print(f"\n{Colors.BLUE}Verifying VPS AI count...{Colors.NC}")
        _vps_verify(app_user, app_root, user_count)

        print(
            f"\n{Colors.GREEN}✓ Synced {user_count} AI players + "
            f"{p_n} Lotties / {d_n} designs to VPS{Colors.NC}"
        )
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
