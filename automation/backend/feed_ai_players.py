#!/usr/bin/env python3
# dash Feed 500 AI players from JSON seed
"""Interactive AI player feed — run via wfrun.

Loads automation/backend/data/ai_players_500.json (username + kinName).
For each player: create user → ensure_avari_profile (live starter pack) →
claim_kin (random template/region/color/background + template Lottie face).

AI identity: avari_profiles.notes = ai_seed:v1 and email *@arcoriaiplayer.app
(see modules.players.players_service.AI_EMAIL_DOMAIN / AI_SEED_MARKER).

Kin faces: claim body sends metadata only (no inline Lottie). Server claim bake
loads the catalog template, applies random part/embed customs, then writes
/media/kin/players/{id}.json. Host runs that cannot write Docker's
/data/uploads stage under .tmp/ai_feed_uploads and sync into the
arcori_uploads volume when present.

Prompts on each run (unless flags set):
  1) Clear existing AI players first?
  2) On email conflict: replace or skip?

Use --dry-run to validate seed + print sample claim bodies without DB writes.
"""

from __future__ import annotations

import argparse
import json
import os
import random
import secrets
import string
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent
PYTHON_BIN = REPO_ROOT / "app_codebase" / "python_base_05" / "bin"
FLUTTER_KIN = REPO_ROOT / "app_codebase" / "flutter_base_06" / "assets" / "kin"
LOTTIE_KIN = REPO_ROOT / "assets" / "lottie" / "kin"
DEFAULT_JSON = SCRIPT_DIR / "data" / "ai_players_500.json"

EMAIL_DOMAIN_DEFAULT = "arcoriaiplayer.app"


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


def _validate_seed_players(players: list[Any]) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    seen_u: set[str] = set()
    seen_k: set[str] = set()
    for idx, raw in enumerate(players, start=1):
        if not isinstance(raw, dict):
            raise ValueError(f"players[{idx}] must be an object")
        username = str(raw.get("username") or "").strip()
        kin_name = str(raw.get("kinName") or raw.get("chosenName") or "").strip()
        if not username or not kin_name:
            raise ValueError(f"players[{idx}] needs username and kinName")
        ul = username.lower()
        kl = kin_name.lower()
        if ul in seen_u:
            raise ValueError(f"duplicate username: {username}")
        if kl in seen_k:
            raise ValueError(f"duplicate kinName: {kin_name}")
        seen_u.add(ul)
        seen_k.add(kl)
        out.append({"username": username, "kinName": kin_name})
    return out


def _stable_user_id(email: str) -> uuid.UUID:
    return uuid.uuid5(uuid.NAMESPACE_URL, f"arcori:ai-player:{email.strip().lower()}")


def _email_for(username: str, domain: str) -> str:
    local = username.strip().lower()
    dom = domain.strip().lower().lstrip("@")
    return f"{local}@{dom}"


def _random_password(length: int = 24) -> str:
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))


def _display_name_from_username(username: str) -> str:
    raw = username.replace("_", " ").strip()
    if not raw:
        return "Avari"
    return raw[:64]


# --- Kin option pools ---------------------------------------------------------


def _load_kin_catalog() -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    types_path = FLUTTER_KIN / "types.json"
    kins_path = FLUTTER_KIN / "kins.json"
    types_doc = json.loads(types_path.read_text(encoding="utf-8"))
    kins_doc = json.loads(kins_path.read_text(encoding="utf-8"))
    types = types_doc.get("types") if isinstance(types_doc, dict) else None
    kins = kins_doc.get("kins") if isinstance(kins_doc, dict) else None
    if not isinstance(types, list) or not types:
        raise RuntimeError(f"no types in {types_path}")
    if not isinstance(kins, list) or not kins:
        raise RuntimeError(f"no kins in {kins_path}")
    return types, kins


def _load_customs_by_serial() -> dict[str, dict[str, Any]]:
    path = FLUTTER_KIN / "customs.json"
    doc = json.loads(path.read_text(encoding="utf-8"))
    rows = doc.get("customs") if isinstance(doc, dict) else None
    if not isinstance(rows, list) or not rows:
        raise RuntimeError(f"no customs in {path}")
    out: dict[str, dict[str, Any]] = {}
    for row in rows:
        if not isinstance(row, dict):
            continue
        serial = str(row.get("serial") or "").strip()
        if serial:
            out[serial] = row
    if not out:
        raise RuntimeError(f"no customs in {path}")
    return out


# Random AI Kin look: apply each adjustable custom ~half the time; when applied,
# pick a value at 30–80% of the allowed range from default (noticeable, not max).
_P_APPLY_PART_CUSTOM = 0.5
_P_INCLUDE_EMBED = 0.45
_P_EMBED_HUE = 0.5
_P_EMBED_LIGHT = 0.5
_INTENSITY_LO = 0.3
_INTENSITY_HI = 0.8

_CUS_EMBED = "CUS-0006"
_CUS_EMBED_HUE = "CUS-0009"
_CUS_EMBED_LIGHT = "CUS-0010"
_PART_ADJUST_TYPES = frozenset({"hue", "saturation", "lightDark", "color"})


def _snap_custom_value(
    value: float,
    *,
    vmin: float,
    vmax: float,
    step: float | None,
) -> float | int:
    if step is not None and step > 0:
        n = round((value - vmin) / step)
        value = vmin + n * step
    value = max(vmin, min(vmax, value))
    if step is not None and abs(step - round(step)) < 1e-9 and step >= 1:
        return int(round(value))
    return round(value, 4)


def _random_numeric_at_intensity(
    params: dict[str, Any],
    rng: random.Random,
) -> float | int:
    """Pick a value at 0.3–0.8 of the distance from default toward a range end."""
    vmin = float(params.get("min", 0))
    vmax = float(params.get("max", 0))
    default = float(params.get("default", 0))
    step_raw = params.get("step")
    step = float(step_raw) if isinstance(step_raw, (int, float)) else None
    toward_hi = abs(vmax - default)
    toward_lo = abs(default - vmin)
    intensity = rng.uniform(_INTENSITY_LO, _INTENSITY_HI)
    if toward_hi <= 1e-9 and toward_lo <= 1e-9:
        return _snap_custom_value(default, vmin=vmin, vmax=vmax, step=step)
    # Prefer a random non-zero side when both exist.
    if toward_hi > 1e-9 and toward_lo > 1e-9:
        if rng.random() < 0.5:
            value = default + intensity * toward_hi
        else:
            value = default - intensity * toward_lo
    elif toward_hi > 1e-9:
        value = default + intensity * toward_hi
    else:
        value = default - intensity * toward_lo
    return _snap_custom_value(value, vmin=vmin, vmax=vmax, step=step)


def _build_random_applied(
    kin_row: dict[str, Any],
    customs: dict[str, dict[str, Any]],
    rng: random.Random,
) -> list[dict[str, Any]]:
    """Random part tints + random embeds (with optional embed hue/lightDark)."""
    applied: list[dict[str, Any]] = []
    parts = kin_row.get("parts")
    if not isinstance(parts, list):
        return applied

    embed_hue_meta = customs.get(_CUS_EMBED_HUE) or {}
    embed_light_meta = customs.get(_CUS_EMBED_LIGHT) or {}
    embed_hue_params = (
        embed_hue_meta.get("params")
        if isinstance(embed_hue_meta.get("params"), dict)
        else {"min": -180, "max": 180, "step": 1, "default": 0}
    )
    embed_light_params = (
        embed_light_meta.get("params")
        if isinstance(embed_light_meta.get("params"), dict)
        else {"min": -1, "max": 1, "step": 0.01, "default": 0}
    )

    for part in parts:
        if not isinstance(part, dict):
            continue
        part_serial = str(part.get("serial") or "").strip()
        if not part_serial:
            continue
        allowed = part.get("allowedCustomSerials")
        if not isinstance(allowed, list):
            allowed = []
        allowed_set = {str(s).strip() for s in allowed if str(s).strip()}

        for cserial in sorted(allowed_set):
            if cserial == _CUS_EMBED:
                continue
            meta = customs.get(cserial)
            if not isinstance(meta, dict):
                continue
            ctype = str(meta.get("customType") or "").strip()
            if ctype not in _PART_ADJUST_TYPES:
                continue
            if rng.random() >= _P_APPLY_PART_CUSTOM:
                continue
            params = meta.get("params") if isinstance(meta.get("params"), dict) else {}
            if ctype == "color":
                colors = params.get("allowedColors")
                if not isinstance(colors, list) or not colors:
                    continue
                picks = [str(c).strip() for c in colors if str(c).strip()]
                if not picks:
                    continue
                value: Any = rng.choice(picks)
            else:
                value = _random_numeric_at_intensity(params, rng)
            applied.append(
                {
                    "partSerial": part_serial,
                    "customSerial": cserial,
                    "value": value,
                }
            )

        if _CUS_EMBED not in allowed_set:
            continue
        pool = part.get("embedPoolSerials")
        if not isinstance(pool, list) or not pool:
            continue
        selected: dict[str, dict[str, float]] = {}
        for raw_emb in pool:
            emb = str(raw_emb or "").strip()
            if not emb or rng.random() >= _P_INCLUDE_EMBED:
                continue
            tint: dict[str, float] = {}
            if rng.random() < _P_EMBED_HUE:
                tint["hue"] = float(
                    _random_numeric_at_intensity(embed_hue_params, rng)
                )
            if rng.random() < _P_EMBED_LIGHT:
                tint["lightDark"] = float(
                    _random_numeric_at_intensity(embed_light_params, rng)
                )
            selected[emb] = tint
        if selected:
            applied.append(
                {
                    "partSerial": part_serial,
                    "customSerial": _CUS_EMBED,
                    "value": selected,
                }
            )
    return applied


def _region_codes_excluding_rby() -> list[str]:
    from modules.avari.kin_genesis import EXCLUDED_KIN_REGION
    from modules.catalog import catalog_loader as loader

    meta = loader.load_meta("regions")
    regions = meta.get("regions") if isinstance(meta, dict) else None
    out: list[str] = []
    if not isinstance(regions, list):
        return out
    for row in regions:
        if not isinstance(row, dict):
            continue
        code = str(row.get("regionCode") or "").strip().upper()
        if code and code != EXCLUDED_KIN_REGION:
            out.append(code)
    return out


def _ensure_kin_media_env() -> None:
    if os.environ.get("CATALOG_KIN_MEDIA_ROOT", "").strip():
        return
    if LOTTIE_KIN.is_dir():
        os.environ["CATALOG_KIN_MEDIA_ROOT"] = str(LOTTIE_KIN)


def _ensure_host_upload_root(repo_root: Path) -> Path:
    """Point UPLOAD_ROOT at a writable host dir (Docker /data/uploads is in-container)."""
    current = os.environ.get("UPLOAD_ROOT", "").strip()
    if current:
        path = Path(current)
        if path.is_dir() and os.access(path, os.W_OK):
            return path
        # Explicit but missing (e.g. /data/uploads from .env.local on host) → stage.
    staging = repo_root / ".tmp" / "ai_feed_uploads"
    staging.mkdir(parents=True, exist_ok=True)
    os.environ["UPLOAD_ROOT"] = str(staging)
    return staging


def _sync_uploads_to_api_volume(staging: Path) -> None:
    """Copy staged kin/designs + kin/players into the local compose uploads volume."""
    if not staging.is_dir():
        return
    designs = staging / "kin" / "designs"
    players = staging / "kin" / "players"
    if not designs.is_dir() and not players.is_dir():
        return
    volume = "arcori_fastapi_dart_flutter_arcori_uploads"
    try:
        import subprocess

        cmd = [
            "docker",
            "run",
            "--rm",
            "-v",
            f"{volume}:/data/uploads",
            "-v",
            f"{staging}:/src:ro",
            "alpine",
            "sh",
            "-c",
            (
                "mkdir -p /data/uploads/kin/designs /data/uploads/kin/players && "
                "if [ -d /src/kin/designs ]; then cp -a /src/kin/designs/. "
                "/data/uploads/kin/designs/; fi && "
                "if [ -d /src/kin/players ]; then cp -a /src/kin/players/. "
                "/data/uploads/kin/players/; fi && "
                "echo designs=$(ls /data/uploads/kin/designs 2>/dev/null | wc -l) "
                "players=$(ls /data/uploads/kin/players 2>/dev/null | wc -l)"
            ),
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        if result.returncode != 0:
            print(
                f"⚠️  Could not sync uploads to Docker volume {volume}: "
                f"{(result.stderr or result.stdout or '').strip()}",
                file=sys.stderr,
            )
            return
        print(f"📦 Synced uploads → volume {volume}: {(result.stdout or '').strip()}")
    except OSError as exc:
        print(f"⚠️  Docker sync skipped: {exc}", file=sys.stderr)


def _catalog_lottie_disk_path(lottie_url: str) -> Path:
    """Map /catalog-media/kin/... → assets/lottie/kin/..."""
    raw = (lottie_url or "").strip()
    marker = "/catalog-media/kin/"
    if marker in raw:
        rel = raw.split(marker, 1)[1].lstrip("/")
    elif raw.startswith("kin/"):
        rel = raw[len("kin/") :]
    else:
        raise FileNotFoundError(f"unexpected kin lottieUrl: {lottie_url!r}")
    path = LOTTIE_KIN / rel
    if not path.is_file():
        raise FileNotFoundError(f"missing template Lottie: {path}")
    return path


def _load_template_lottie(kin_row: dict[str, Any]) -> dict[str, Any]:
    url = str(kin_row.get("lottieUrl") or "").strip()
    if not url:
        raise RuntimeError(
            f"kin template {kin_row.get('serial')!r} missing lottieUrl"
        )
    path = _catalog_lottie_disk_path(url)
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise RuntimeError(f"template Lottie is not an object: {path}")
    return data


def build_random_kin_claim_body(
    *,
    kin_name: str,
    rng: random.Random | None = None,
) -> dict[str, Any]:
    """Build claim_kin body: random template/region/color/background + applied."""
    from modules.avari.kin_backgrounds import list_kin_backgrounds
    from modules.avari.kin_genesis import ALLOWED_ARCORI_COLORS, pick_echo_color
    from modules.avari.rejected_words import is_rejected_kin_name

    picker = rng or random.Random()
    chosen = kin_name.strip()
    if not chosen or is_rejected_kin_name(chosen):
        raise ValueError(f"invalid kinName: {kin_name!r}")

    types, kins = _load_kin_catalog()
    customs = _load_customs_by_serial()
    type_row = picker.choice(types)
    type_serial = str(type_row.get("serial") or "").strip()
    if not type_serial:
        raise RuntimeError("kin type missing serial")

    typed = [
        k
        for k in kins
        if isinstance(k, dict) and str(k.get("typeSerial") or "").strip() == type_serial
    ]
    if not typed:
        typed = [k for k in kins if isinstance(k, dict)]
    kin_row = picker.choice(typed)
    kin_serial = str(kin_row.get("serial") or "").strip()
    if not kin_serial:
        raise RuntimeError("kin template missing serial")

    regions = _region_codes_excluding_rby()
    if not regions:
        raise RuntimeError("no assignable region codes")
    region_code = picker.choice(regions)

    color = pick_echo_color()
    if color not in ALLOWED_ARCORI_COLORS:
        color = sorted(ALLOWED_ARCORI_COLORS)[0]

    _ensure_kin_media_env()
    bg_doc = list_kin_backgrounds()
    bg_list = bg_doc.get("backgrounds") if isinstance(bg_doc, dict) else None
    if not isinstance(bg_list, list):
        bg_list = []
    background = picker.choice(bg_list) if bg_list else None

    # Verify template exists on disk; claim_kin loads + bakes it server-side.
    _load_template_lottie(kin_row)
    applied = _build_random_applied(kin_row, customs, picker)

    body: dict[str, Any] = {
        "kinSerial": kin_serial,
        "typeSerial": type_serial,
        "chosenName": chosen[:64],
        "regionCode": region_code,
        "color": color,
        "applied": applied,
    }
    if isinstance(background, dict):
        body["background"] = background
    return body


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


def _mark_ai_onboarded(session, user_id: uuid.UUID, *, marker: str) -> None:
    from sqlalchemy import text

    session.execute(
        text(
            """
            UPDATE avari_profiles
            SET notes = :marker,
                onboarding_completed = true,
                onboarding_guided_practice_done = true,
                onboarding_intros_done = true,
                updated_at = :now
            WHERE user_id = :uid
            """
        ),
        {
            "marker": marker,
            "uid": user_id,
            "now": datetime.now(timezone.utc),
        },
    )


def _insert_player(
    session,
    *,
    username: str,
    kin_name: str,
    email: str,
    password_hash: str,
    marker: str,
    rng: random.Random,
) -> tuple[uuid.UUID, dict[str, Any]]:
    """Create user + ensure profile (starter grant) in this session; return claim body."""
    from models.user import User
    from modules.avari.avari_repository import ensure_avari_profile

    user_id = _stable_user_id(email)
    taken = session.get(User, user_id)
    if taken is not None:
        user_id = uuid.uuid4()

    if _username_taken(session, username, exclude_id=None):
        raise RuntimeError(f"username already taken: {username}")

    user = User(
        id=user_id,
        username=username[:64],
        email=email[:255],
        password_hash=password_hash,
        is_guest=False,
        email_verified_at=datetime.now(timezone.utc),
    )
    session.add(user)
    session.flush()

    display = _display_name_from_username(username)
    ensure_avari_profile(session, user_id=user_id, display_name=display)
    _mark_ai_onboarded(session, user_id, marker=marker)

    claim_body = build_random_kin_claim_body(kin_name=kin_name, rng=rng)
    return user_id, claim_body


def _dry_run(
    *,
    players: list[dict[str, str]],
    email_domain: str,
    marker: str,
    sample: int = 3,
) -> None:
    _ensure_python_bin_on_path()
    _ensure_kin_media_env()

    from modules.avari.kin_genesis import ALLOWED_ARCORI_COLORS, EXCLUDED_KIN_REGION
    from modules.avari.rejected_words import is_rejected_kin_name
    from modules.players.players_service import AI_EMAIL_DOMAIN, AI_SEED_MARKER

    print("—— dry-run (no DB writes) ——")
    print(f"   players: {len(players)}")
    print(f"   seed emailDomain: @{email_domain.lstrip('@')}")
    print(f"   runtime AI_EMAIL_DOMAIN: {AI_EMAIL_DOMAIN}")
    print(f"   seed marker: {marker} (runtime {AI_SEED_MARKER})")
    if f"@{email_domain.lstrip('@')}" != AI_EMAIL_DOMAIN:
        print(
            "⚠️  seed emailDomain does not match AI_EMAIL_DOMAIN — fix before real feed",
            file=sys.stderr,
        )
    if marker != AI_SEED_MARKER:
        print(
            "⚠️  seed marker does not match AI_SEED_MARKER — fix before real feed",
            file=sys.stderr,
        )

    rejected = [p for p in players if is_rejected_kin_name(p["kinName"])]
    if rejected:
        print(f"❌ {len(rejected)} kinName(s) rejected by word filter, e.g. {rejected[0]}")
        sys.exit(1)

    regions = _region_codes_excluding_rby()
    types, kins = _load_kin_catalog()
    print(f"   kin types: {len(types)}  templates: {len(kins)}  regions: {regions}")

    rng = random.Random(42)
    n = min(sample, len(players))
    for i in range(n):
        p = players[i]
        email = _email_for(p["username"], email_domain)
        body = build_random_kin_claim_body(kin_name=p["kinName"], rng=rng)
        assert isinstance(body["applied"], list)
        assert body["color"] in ALLOWED_ARCORI_COLORS
        assert body["regionCode"] != EXCLUDED_KIN_REGION
        assert body["regionCode"] in regions
        assert "lottie" not in body
        print(
            f"   sample[{i}] user={p['username']} email={email} "
            f"kinName={p['kinName']!r} "
            f"type={body['typeSerial']} kin={body['kinSerial']} "
            f"region={body['regionCode']} color={body['color']} "
            f"bg={'yes' if body.get('background') else 'no'} "
            f"applied={len(body['applied'])} lottie=server-bake"
        )
    print("✅ dry-run OK")


def _feed_players(
    *,
    players: list[dict[str, str]],
    email_domain: str,
    marker: str,
    conflict_mode: str,
    clear_first: bool,
    repo_root: Path,
    rng_seed: int | None = None,
) -> dict[str, int]:
    _ensure_python_bin_on_path()
    _ensure_kin_media_env()
    upload_dir = _ensure_host_upload_root(repo_root)
    print(f"   UPLOAD_ROOT: {upload_dir}")

    from core.state.session_scope import session_scope
    from modules.auth.password_utils import hash_password
    from modules.avari.avari_service import claim_kin
    from modules.players.players_service import AI_EMAIL_DOMAIN, AI_SEED_MARKER

    domain = email_domain.strip().lower().lstrip("@")
    if f"@{domain}" != AI_EMAIL_DOMAIN:
        print(
            f"⚠️  Using seed domain @{domain}; runtime AI_EMAIL_DOMAIN={AI_EMAIL_DOMAIN}",
            file=sys.stderr,
        )
    if marker != AI_SEED_MARKER:
        print(
            f"⚠️  Using seed marker {marker!r}; runtime AI_SEED_MARKER={AI_SEED_MARKER!r}",
            file=sys.stderr,
        )

    cleared = 0
    if clear_first:
        cleared = _clear_ai_players(email_domain=domain, marker=marker)
        print(f"🧹 Cleared existing AI players: {cleared}")

    rng = random.Random(rng_seed if rng_seed is not None else secrets.randbits(32))

    inserted = 0
    replaced = 0
    skipped = 0
    errors = 0

    for idx, player in enumerate(players, start=1):
        username = player["username"]
        kin_name = player["kinName"]
        email = _email_for(username, domain)
        password_hash = hash_password(_random_password())
        claim_body: dict[str, Any] | None = None
        user_id: uuid.UUID | None = None

        try:
            with session_scope() as session:
                with session.begin_nested():
                    existing_id = _find_user_id_by_email(session, email)
                    if existing_id is not None:
                        if conflict_mode == "skip":
                            skipped += 1
                            continue
                        _delete_user_by_id(session, existing_id)
                        user_id, claim_body = _insert_player(
                            session,
                            username=username,
                            kin_name=kin_name,
                            email=email,
                            password_hash=password_hash,
                            marker=marker,
                            rng=rng,
                        )
                        replaced += 1
                    else:
                        user_id, claim_body = _insert_player(
                            session,
                            username=username,
                            kin_name=kin_name,
                            email=email,
                            password_hash=password_hash,
                            marker=marker,
                            rng=rng,
                        )
                        inserted += 1

            if user_id is not None and claim_body is not None:
                claim_kin(str(user_id), claim_body)
                # claim_kin may create profile path without our notes if race; re-stamp
                with session_scope() as session:
                    _mark_ai_onboarded(session, user_id, marker=marker)
        except Exception as exc:  # noqa: BLE001 — continue remaining rows
            errors += 1
            print(f"⚠️  fail {username} <{email}>: {exc}", file=sys.stderr)
            if user_id is not None:
                try:
                    with session_scope() as session:
                        _delete_user_by_id(session, user_id)
                except Exception:  # noqa: BLE001
                    pass

        if idx % 50 == 0:
            print(f"… {idx}/{len(players)}")

    _sync_uploads_to_api_volume(upload_dir)

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
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate seed + sample claim bodies; no DB writes",
    )
    parser.add_argument(
        "--dry-run-samples",
        type=int,
        default=3,
        help="How many sample claim bodies to print in --dry-run (default 3)",
    )
    args = parser.parse_args()

    seed_path = args.file if args.file.is_absolute() else (repo_root / args.file)
    if not seed_path.is_file() and args.file == DEFAULT_JSON:
        seed_path = DEFAULT_JSON

    print(f"🤖 wfrun ({mode}): feed AI players")
    print(f"   root: {repo_root}")
    print(f"   file: {seed_path}")

    seed = _load_seed(seed_path)
    try:
        players = _validate_seed_players(seed["players"])
    except ValueError as exc:
        print(f"❌ {exc}", file=sys.stderr)
        sys.exit(1)

    marker = str(seed.get("marker") or "ai_seed:v1")
    email_domain = str(seed.get("emailDomain") or EMAIL_DOMAIN_DEFAULT)

    print(f"   players in JSON: {len(players)}")
    print(f"   email domain: {email_domain}")
    print(f"   marker: {marker}")

    if args.dry_run:
        _dry_run(
            players=players,
            email_domain=email_domain,
            marker=marker,
            sample=max(1, args.dry_run_samples),
        )
        return

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
        players=players,
        email_domain=email_domain,
        marker=marker,
        conflict_mode=conflict_mode,
        clear_first=clear_first,
        repo_root=repo_root,
    )
    print(
        "✅ Done — "
        f"cleared={stats['cleared']} inserted={stats['inserted']} "
        f"replaced={stats['replaced']} skipped={stats['skipped']} "
        f"errors={stats['errors']} total={stats['total']}"
    )


if __name__ == "__main__":
    main()
