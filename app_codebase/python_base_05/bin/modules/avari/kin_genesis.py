"""Kin catalog design builder — series from catalog CURRENT_SERIES (GEN001 launch)."""

from __future__ import annotations

import re
from datetime import datetime, timezone
from typing import Any

from modules.catalog.current_series import (
    CURRENT_SERIES,
    current_id_token,
    current_series,
)

# Keys on a regular Genesis design (e.g. Tiger in animals.json) — parity lock.
REGULAR_ARCORI_DESIGN_KEYS: frozenset[str] = frozenset(
    {
        "internalId",
        "themeCode",
        "designCode",
        "designFamily",
        "design",
        "inspiration",
        "location",
        "affinity",
        "hostility",
        "generation",
        "type",
        "theme",
        "subtheme",
        "style",
        "finish",
        "color",
        "effect",
        "printedRarity",
        "selectionWeight",
        "series",
        "worldState",
        "seasonState",
        "artworkPrompt",
        "loreDescription",
        "legacy",
    }
)

# Back-compat alias — prefer CURRENT_SERIES / current_series().
CURRENT_KIN_SERIES: dict[str, Any] = CURRENT_SERIES

# Same accents as Flutter arcori_palette.dart / kArcoriAccentHexes.
ALLOWED_ARCORI_COLORS: frozenset[str] = frozenset(
    {
        "#C6A15B",
        "#A8B0B8",
        "#7A3142",
        "#B8734A",
        "#D8CDB8",
        "#4E7A78",
        "#7A8458",
        "#3E5270",
        "#B5817A",
        "#5C4A58",
    }
)

EXCLUDED_KIN_REGION = "RBY"

_TYPE_DISPLAY: dict[str, str] = {
    "KTYPE-0001": "Guardians",
    "KTYPE-0002": "Entelairs",
    "KTYPE-0003": "Walkies",
    "guardians": "Guardians",
    "entelairs": "Entelairs",
    "walkies": "Walkies",
}


def normalize_color(raw: str | None) -> str | None:
    if raw is None:
        return None
    s = str(raw).strip().upper()
    if not s.startswith("#"):
        s = f"#{s}"
    if len(s) != 7:
        return None
    if s not in ALLOWED_ARCORI_COLORS:
        return None
    return s


def subtheme_for_type(type_serial: str, type_code: str | None = None) -> str:
    key = (type_serial or "").strip()
    if key in _TYPE_DISPLAY:
        return _TYPE_DISPLAY[key]
    code = (type_code or "").strip().lower()
    if code in _TYPE_DISPLAY:
        return _TYPE_DISPLAY[code]
    return key or "Kin"


def _slug_design_code(name: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9]+", "", (name or "").strip())
    if not cleaned:
        return "KIN"
    return cleaned[:12].upper()


def _player_token(username: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9]+", "", (username or "").strip())
    if not cleaned:
        cleaned = "PLY"
    return cleaned[:12].upper()


def mint_internal_id(*, username: str, seq: int) -> str:
    """Mint `KIN-…-{idToken}-####` using catalog CURRENT_SERIES (GEN001 today)."""
    token = _player_token(username)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M")
    series_token = current_id_token()
    return f"KIN-{token}{stamp}-{series_token}-{seq:04d}"


def region_affinity_hostility(region_code: str) -> tuple[list[str], list[str]]:
    from modules.catalog import catalog_loader as loader

    meta = loader.load_meta("regions")
    regions = meta.get("regions") if isinstance(meta, dict) else None
    if not isinstance(regions, list):
        return [], []
    code = (region_code or "").strip().upper()
    for row in regions:
        if not isinstance(row, dict):
            continue
        if str(row.get("regionCode") or "").strip().upper() != code:
            continue
        rel = row.get("relationships")
        if not isinstance(rel, dict):
            return [], []
        aff = rel.get("affinity")
        hos = rel.get("hostility")
        affinity = [str(x) for x in aff] if isinstance(aff, list) else []
        hostility = [str(x) for x in hos] if isinstance(hos, list) else []
        return affinity, hostility
    return [], []


def lottie_public_url(internal_id: str) -> str:
    from modules.catalog.kin_design_store import lottie_public_url as _url

    return _url(internal_id)


def build_kin_catalog_design(
    *,
    internal_id: str,
    chosen_name: str,
    region_code: str,
    color: str,
    subtheme: str,
    player_id: str,
    style: str = "Chibi",
    finish: str = "Standard",
    effect: str = "None",
) -> dict[str, Any]:
    """Build a design object with the same keys as a regular Genesis Arcori."""
    name = (chosen_name or "").strip() or "Kin"
    design_code = _slug_design_code(name)
    family = re.sub(r"[^A-Za-z0-9]+", "_", name.upper()).strip("_") or "KIN"
    affinity, hostility = region_affinity_hostility(region_code)
    series_cfg = current_series()
    gen = dict(series_cfg["generation"])
    gen["creator"] = {"type": "player", "playerId": player_id}
    legacy = dict(series_cfg["legacy"])
    series_display = series_cfg["seriesDisplay"]

    design: dict[str, Any] = {
        "internalId": internal_id,
        "themeCode": "KIN",
        "designCode": design_code,
        "designFamily": family,
        "design": name,
        "inspiration": None,
        "location": {
            "regionCode": region_code.strip().upper(),
            "locationCode": None,
            "latitude": None,
            "longitude": None,
            "radiusMeters": None,
        },
        "affinity": affinity,
        "hostility": hostility,
        "generation": gen,
        "type": "arcori",
        "theme": "Kin",
        "subtheme": subtheme,
        "style": style,
        "finish": finish,
        "color": color,
        "effect": effect,
        "printedRarity": "Common",
        "selectionWeight": None,
        "series": series_display,
        "worldState": "Active",
        "seasonState": "Active",
        "artworkPrompt": (
            f"Give me an image with a Kin Arcori from the {subtheme} lineage "
            f"named {name} in {style.lower()} style with a {finish.lower()} finish "
            f"and {effect.lower()} effect. Use a background visually related to the "
            f"Genesis origins of Velora. No borders, no frames. The subject should be "
            f"horizontally and vertically centered. The subject should fill around 2/4 "
            f"of the total image size. The image must use a 1:1 aspect ratio in webp "
            f"format and named {internal_id}.webp"
        ),
        "loreDescription": (
            f"The first generation of the {name} lineage. This Genesis Arcori belongs "
            f"to the {subtheme} Kin and marks the beginning of a unique family within Velora."
        ),
        "legacy": legacy,
    }
    return design


def assert_design_key_parity(design: dict[str, Any]) -> None:
    keys = frozenset(design.keys())
    if keys != REGULAR_ARCORI_DESIGN_KEYS:
        missing = REGULAR_ARCORI_DESIGN_KEYS - keys
        extra = keys - REGULAR_ARCORI_DESIGN_KEYS
        raise ValueError(f"Kin design key mismatch missing={missing} extra={extra}")
