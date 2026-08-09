#!/usr/bin/env python3
# dash Feed 500 AI players from JSON seed
"""Interactive AI player feed — run via wfrun.

Loads automation/backend/data/ai_players_500.json and upserts users + Avari
profile rows (starter access + starter slammer).

Prompts on each run:
  1) Clear existing AI players first? (email domain / marker)
  2) On email conflict: replace or skip?
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent
PYTHON_BIN = REPO_ROOT / "app_codebase" / "python_base_05" / "bin"
DEFAULT_JSON = SCRIPT_DIR / "data" / "ai_players_500.json"

STARTER_DESIGNS_FALLBACK = (
    "ANM-TIG-GEN001-0001",
    "ANM-WTI-GEN001-0002",
    "ANM-LIO-GEN001-0003",
    "ANM-BPA-GEN001-0004",
    "ANM-CHE-GEN001-0005",
    "ANM-LEO-GEN001-0006",
    "ANM-SNL-GEN001-0007",
    "ANM-JAG-GEN001-0008",
    "ANM-AWO-GEN001-0009",
    "ANM-GWO-GEN001-0010",
)
STARTER_SLAMMER_FALLBACK = "SLM-STR-GEN001-0001"


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


def _prompt_yes_no(label: str, *, default: bool = False) -> bool:
    hint = "Y/n" if default else "y/N"
    raw = input(f"{label} [{hint}]: ").strip().lower()
    if not raw:
        return default
    if raw in {"y", "yes", "1"}:
        return True
    if raw in {"n", "no", "0"}:
        return False
    print(f"❌ Unknown answer: {raw!r} (use y/n)", file=sys.stderr)
    sys.exit(1)


def _prompt_conflict_mode(explicit: str | None) -> str:
    if explicit:
        mode = explicit.strip().lower()
        if mode in {"replace", "skip"}:
            return mode
        print(f"❌ Invalid --on-conflict {explicit!r} (replace|skip)", file=sys.stderr)
        sys.exit(1)
    print()
    print("Email already exists:")
    print("  1) replace — delete existing user (cascade) then insert seed")
    print("  2) skip    — leave existing user unchanged")
    raw = input("Choose [replace/skip]: ").strip().lower()
    if raw in {"1", "r", "replace"}:
        return "replace"
    if raw in {"2", "s", "skip"}:
        return "skip"
    print(f"❌ Unknown choice: {raw!r} (use replace or skip)", file=sys.stderr)
    sys.exit(1)


def _load_seed(path: Path) -> dict[str, Any]:
    if not path.is_file():
        print(f"❌ Seed JSON not found: {path}", file=sys.stderr)
        sys.exit(1)
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        print("❌ Seed JSON root must be an object", file=sys.stderr)
        sys.exit(1)
    players = data.get("players")
    if not isinstance(players, list) or not players:
        print("❌ Seed JSON needs a non-empty players[] list", file=sys.stderr)
        sys.exit(1)
    return data


def _stable_user_id(email: str) -> uuid.UUID:
    return uuid.uuid5(uuid.NAMESPACE_URL, f"arcori:ai-player:{email.strip().lower()}")


def _clear_ai_players(*, email_domain: str, marker: str) -> int:
    from core.state.session_scope import session_scope
    from sqlalchemy import text

    domain = email_domain.strip().lower().lstrip("@")
    with session_scope() as session:
        result = session.execute(
            text(
                """
                DELETE FROM users u
                WHERE lower(u.email) LIKE :email_pattern
                   OR EXISTS (
                        SELECT 1 FROM avari_profiles a
                        WHERE a.user_id = u.id AND a.notes = :marker
                   )
                """
            ),
            {
                "email_pattern": f"%@{domain}",
                "marker": marker,
            },
        )
        return int(result.rowcount or 0)


def _delete_user_by_id(session, user_id: uuid.UUID) -> None:
    from sqlalchemy import text

    session.execute(
        text("DELETE FROM users WHERE id = :id"),
        {"id": user_id},
    )


def _find_user_id_by_email(session, email: str) -> uuid.UUID | None:
    from sqlalchemy import text

    row = session.execute(
        text("SELECT id FROM users WHERE lower(email) = lower(:email)"),
        {"email": email},
    ).fetchone()
    return row[0] if row else None


def _username_taken(session, username: str, *, exclude_id: uuid.UUID | None) -> bool:
    from sqlalchemy import text

    if exclude_id is None:
        row = session.execute(
            text("SELECT 1 FROM users WHERE lower(username) = lower(:u)"),
            {"u": username},
        ).fetchone()
    else:
        row = session.execute(
            text(
                """
                SELECT 1 FROM users
                WHERE lower(username) = lower(:u) AND id <> :id
                """
            ),
            {"u": username, "id": exclude_id},
        ).fetchone()
    return row is not None


def _insert_player(
    session,
    *,
    player: dict[str, Any],
    password_hash: str,
    marker: str,
    defaults: dict[str, Any],
    now: datetime,
) -> uuid.UUID:
    from sqlalchemy import text

    email = str(player["email"]).strip().lower()
    username = str(player["username"]).strip()
    display_name = str(player.get("displayName") or username).strip() or username
    user_id = _stable_user_id(email)

    # Avoid PK collision if a non-AI row somehow reused this UUID.
    taken = session.execute(
        text("SELECT 1 FROM users WHERE id = :id"),
        {"id": user_id},
    ).fetchone()
    if taken is not None:
        user_id = uuid.uuid4()

    if _username_taken(session, username, exclude_id=None):
        raise RuntimeError(f"username already taken: {username}")

    email_verified = bool(defaults.get("emailVerified", True))
    is_guest = bool(defaults.get("isGuest", False))
    titles = defaults.get("titles") or ["Avari"]
    if not isinstance(titles, list):
        titles = ["Avari"]
    primary_title = str(defaults.get("primaryTitle") or "Avari")
    starter_ids = defaults.get("starterDesignIds") or list(STARTER_DESIGNS_FALLBACK)
    starter_slammer = str(
        defaults.get("starterSlammerId") or STARTER_SLAMMER_FALLBACK
    )
    kin = player.get("kin") if isinstance(player.get("kin"), dict) else {}
    subtheme = str(kin.get("subtheme") or "Entelairs")
    style = str(kin.get("style") or "Chibi")
    finish = str(kin.get("finish") or "Standard")
    effect = str(kin.get("effect") or "None")
    genesis_id = str(kin.get("genesisDesignId") or "KIN-SIL202607092145-GEN001-0001")
    chosen_name = str(kin.get("chosenName") or display_name.split()[0])

    session.execute(
        text(
            """
            INSERT INTO users (
                id, username, email, password_hash, is_guest,
                avatar_url, email_verified_at, created_at, updated_at
            ) VALUES (
                :id, :username, :email, :password_hash, :is_guest,
                NULL, :verified_at, :now, :now
            )
            """
        ),
        {
            "id": user_id,
            "username": username,
            "email": email,
            "password_hash": password_hash,
            "is_guest": is_guest,
            "verified_at": now if email_verified else None,
            "now": now,
        },
    )

    onboarded = bool(defaults.get("onboardingCompleted", True))
    session.execute(
        text(
            """
            INSERT INTO avari_profiles (
                id, user_id, display_name, primary_title, titles,
                rank_xp, rank_level, rank_label,
                gold_fragments, gold_caps,
                matches_played, wins, flips,
                onboarding_completed, onboarding_kin_chosen,
                onboarding_genesis_created, onboarding_starter_granted,
                onboarding_guided_practice_done, onboarding_intros_done,
                daily_login_streak, daily_last_login_reward_at,
                daily_cache_claimed_at, daily_no_miss_streak,
                notifications_push, notes, created_at, updated_at
            ) VALUES (
                :id, :uid, :display_name, :primary_title, CAST(:titles AS jsonb),
                :rank_xp, :rank_level, NULL,
                :gold_fragments, :gold_caps,
                :matches_played, :wins, :flips,
                :onboarded, :onboarded, :onboarded, :onboarded, :onboarded, :onboarded,
                0, NULL, NULL, 0,
                :notifications_push, :notes, :now, :now
            )
            """
        ),
        {
            "id": uuid.uuid4(),
            "uid": user_id,
            "display_name": display_name[:64],
            "primary_title": primary_title[:64],
            "titles": json.dumps(titles),
            "rank_xp": int(player.get("rankXp") or 0),
            "rank_level": int(player.get("rankLevel") or 1),
            "gold_fragments": int(player.get("goldFragments") or 0),
            "gold_caps": int(player.get("goldCaps") or 0),
            "matches_played": int(player.get("matchesPlayed") or 0),
            "wins": int(player.get("wins") or 0),
            "flips": int(player.get("flips") or 0),
            "onboarded": onboarded,
            "notifications_push": bool(defaults.get("notificationsPush", True)),
            "notes": marker,
            "now": now,
        },
    )

    session.execute(
        text(
            """
            INSERT INTO player_kin (
                id, user_id, subtheme, style, finish, effect,
                genesis_design_id, chosen_name, customization,
                created_at, updated_at
            ) VALUES (
                :id, :uid, :subtheme, :style, :finish, :effect,
                :genesis_id, :chosen_name, CAST('{}' AS jsonb), :now, :now
            )
            """
        ),
        {
            "id": uuid.uuid4(),
            "uid": user_id,
            "subtheme": subtheme[:64],
            "style": style[:64],
            "finish": finish[:64],
            "effect": effect[:64],
            "genesis_id": genesis_id[:64],
            "chosen_name": chosen_name[:64],
            "now": now,
        },
    )

    for design_id in starter_ids:
        session.execute(
            text(
                """
                INSERT INTO player_design_access (id, user_id, design_id, source, created_at)
                VALUES (:id, :uid, :design_id, 'starter', :now)
                ON CONFLICT ON CONSTRAINT uq_player_design_access_user_design DO NOTHING
                """
            ),
            {
                "id": uuid.uuid4(),
                "uid": user_id,
                "design_id": str(design_id)[:64],
                "now": now,
            },
        )

    session.execute(
        text(
            """
            INSERT INTO player_slammers (
                id, user_id, design_id, permanent, charges_remaining, source, created_at
            ) VALUES (
                :id, :uid, :design_id, true, NULL, 'starter', :now
            )
            ON CONFLICT ON CONSTRAINT uq_player_slammers_user_design DO NOTHING
            """
        ),
        {
            "id": uuid.uuid4(),
            "uid": user_id,
            "design_id": starter_slammer[:64],
            "now": now,
        },
    )
    return user_id


def _feed_players(
    *,
    seed: dict[str, Any],
    conflict_mode: str,
    clear_first: bool,
) -> dict[str, int]:
    _ensure_python_bin_on_path()
    from core.state.session_scope import session_scope
    from modules.auth.password_utils import hash_password

    marker = str(seed.get("marker") or "ai_seed:v1")
    email_domain = str(seed.get("emailDomain") or "ai.arcori.local")
    password = str(seed.get("defaultPassword") or "aiplayer1!")
    defaults = seed.get("defaults") if isinstance(seed.get("defaults"), dict) else {}
    players = seed["players"]

    cleared = 0
    if clear_first:
        cleared = _clear_ai_players(email_domain=email_domain, marker=marker)
        print(f"🧹 Cleared existing AI players: {cleared}")

    # One bcrypt hash for the shared AI password (500× gensalt would be very slow).
    password_hash = hash_password(password)
    now = datetime.now(timezone.utc)

    inserted = 0
    replaced = 0
    skipped = 0
    errors = 0

    with session_scope() as session:
        for idx, raw in enumerate(players, start=1):
            if not isinstance(raw, dict):
                print(f"⚠️  skip index {idx}: not an object")
                errors += 1
                continue
            email = str(raw.get("email") or "").strip().lower()
            username = str(raw.get("username") or "").strip()
            if not email or not username:
                print(f"⚠️  skip index {idx}: missing email/username")
                errors += 1
                continue
            try:
                with session.begin_nested():
                    existing_id = _find_user_id_by_email(session, email)
                    if existing_id is not None:
                        if conflict_mode == "skip":
                            skipped += 1
                            continue
                        _delete_user_by_id(session, existing_id)
                        _insert_player(
                            session,
                            player=raw,
                            password_hash=password_hash,
                            marker=marker,
                            defaults=defaults,
                            now=now,
                        )
                        replaced += 1
                    else:
                        _insert_player(
                            session,
                            player=raw,
                            password_hash=password_hash,
                            marker=marker,
                            defaults=defaults,
                            now=now,
                        )
                        inserted += 1
            except Exception as exc:  # noqa: BLE001 — continue remaining rows
                errors += 1
                print(f"⚠️  fail {username} <{email}>: {exc}", file=sys.stderr)

            if idx % 50 == 0:
                print(f"… {idx}/{len(players)}")

    return {
        "cleared": cleared,
        "inserted": inserted,
        "replaced": replaced,
        "skipped": skipped,
        "errors": errors,
        "total": len(players),
    }


def main() -> None:
    repo_root = _require_wfrun()
    mode = os.environ["WFRUN_MODE"]

    parser = argparse.ArgumentParser(
        description="Feed AI players from JSON into Postgres (wfrun).",
    )
    parser.add_argument(
        "--file",
        type=Path,
        default=DEFAULT_JSON,
        help=f"Seed JSON path (default: {DEFAULT_JSON})",
    )
    parser.add_argument(
        "--clear-ai",
        choices=("yes", "no"),
        help="Clear existing AI players before feed (prompts if omitted)",
    )
    parser.add_argument(
        "--on-conflict",
        choices=("replace", "skip"),
        help="Email conflict policy (prompts if omitted)",
    )
    args = parser.parse_args()

    seed_path = args.file if args.file.is_absolute() else (repo_root / args.file)
    if not seed_path.is_file() and args.file == DEFAULT_JSON:
        seed_path = DEFAULT_JSON

    print(f"🤖 wfrun ({mode}): feed AI players")
    print(f"   root: {repo_root}")
    print(f"   file: {seed_path}")

    seed = _load_seed(seed_path)
    print(f"   players in JSON: {len(seed['players'])}")
    print(f"   email domain: {seed.get('emailDomain', 'ai.arcori.local')}")
    print(f"   marker: {seed.get('marker', 'ai_seed:v1')}")

    if args.clear_ai is None:
        print()
        clear_first = _prompt_yes_no(
            "Clear existing AI players before feeding?",
            default=False,
        )
    else:
        clear_first = args.clear_ai == "yes"

    conflict_mode = _prompt_conflict_mode(args.on_conflict)

    print()
    print(f"→ clear_ai={clear_first} on_conflict={conflict_mode}")
    stats = _feed_players(
        seed=seed,
        conflict_mode=conflict_mode,
        clear_first=clear_first,
    )
    print(
        "✅ Done — "
        f"cleared={stats['cleared']} inserted={stats['inserted']} "
        f"replaced={stats['replaced']} skipped={stats['skipped']} "
        f"errors={stats['errors']} total={stats['total']}"
    )


if __name__ == "__main__":
    main()
