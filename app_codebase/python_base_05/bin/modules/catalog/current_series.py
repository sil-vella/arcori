"""Current catalog series for newly minted designs (and Kin series).

Launch static Arcori: Genesis / SER001 (`ANM-TIG-SER001-…`, etc.).

Player-created Kin uses **KIN_SERIES** (Kin / SER005) — not Genesis.
Kin **templates** (Flutter `kins.json` / Lottie bases) are claim-only and must
not appear in Velora browse.

To open a new series for future non-Kin minted designs, change CURRENT_SERIES
(and add `data/series/<folder>/`). Do not scatter series tokens in claim/mint
call sites.

Note: `idToken` is the series marker in `internalId` (SER000 Creation …
SER005 Kin). Generation stays on `generation.number` / `roman`.

Art under `assets/images/arcori/` uses numbered series dirs (`000_creation`,
`001_genesis`, …). Catalog JSON folders stay unprefixed (`data/series/genesis/`).
Map via `SERIES_MEDIA_FOLDERS` / `media_folder_for_series`.
"""

from __future__ import annotations

from typing import Any

# series slug (from design `series` / seriesKey) → on-disk art folder under
# assets/images/arcori (and /data/catalog-media in Docker).
SERIES_MEDIA_FOLDERS: dict[str, str] = {
    "creation": "000_creation",
    "genesis": "001_genesis",
    "pioneers": "002_pioneers",
    "foundations": "003_foundations",
    "civilizations": "004_civilizations",
    "kin": "005_kin",
}

# Ordered Velora browse list (slug → display label / seriesKey stamp on designs).
SERIES_CATALOG: tuple[dict[str, str], ...] = (
    {"key": "creation", "label": "Creation", "seriesKey": "Creation"},
    {"key": "genesis", "label": "Genesis", "seriesKey": "Genesis"},
    {"key": "pioneers", "label": "Pioneers", "seriesKey": "Pioneers"},
    {"key": "foundations", "label": "Foundations", "seriesKey": "Foundations"},
    {"key": "civilizations", "label": "Civilizations", "seriesKey": "Civilizations"},
    {"key": "kin", "label": "Kin", "seriesKey": "Kin"},
)

# --- bump here when opening the next series for newly minted non-Kin Arcori ---
CURRENT_SERIES: dict[str, Any] = {
    "seriesKey": "Genesis",
    "seriesDisplay": "Genesis Series",
    "idToken": "SER001",
    "folder": "genesis",
    "mediaFolder": SERIES_MEDIA_FOLDERS["genesis"],
    "generation": {"roman": "I", "number": 1},
    "legacy": {"preservationRequirement": 500, "closureMilestone": 1000},
}

# Player-created Kin only (templates stay outside Velora browse).
KIN_SERIES: dict[str, Any] = {
    "seriesKey": "Kin",
    "seriesDisplay": "Kin",
    "idToken": "SER005",
    "folder": "kin",
    "mediaFolder": SERIES_MEDIA_FOLDERS["kin"],
    "generation": {"roman": "I", "number": 1},
    "legacy": {"preservationRequirement": 500, "closureMilestone": 1000},
}


def _series_slug(value: str) -> str:
    return value.strip().lower().replace(" ", "_")


def media_folder_for_series(series_key: str) -> str:
    """Map series key/display slug to assets/images/arcori/<folder>."""
    slug = _series_slug(series_key)
    if slug in SERIES_MEDIA_FOLDERS:
        return SERIES_MEDIA_FOLDERS[slug]
    # "Genesis Series" / "Pioneers Series" display strings
    if slug.endswith("_series"):
        base = slug[: -len("_series")]
        if base in SERIES_MEDIA_FOLDERS:
            return SERIES_MEDIA_FOLDERS[base]
    # Already a numbered media dir (or unknown → pass through).
    if slug in SERIES_MEDIA_FOLDERS.values():
        return slug
    return slug


def _copy_series(cfg: dict[str, Any]) -> dict[str, Any]:
    return {
        "seriesKey": cfg["seriesKey"],
        "seriesDisplay": cfg["seriesDisplay"],
        "idToken": cfg["idToken"],
        "folder": cfg["folder"],
        "mediaFolder": cfg.get("mediaFolder") or media_folder_for_series(cfg["seriesKey"]),
        "generation": dict(cfg["generation"]),
        "legacy": dict(cfg["legacy"]),
    }


def current_series() -> dict[str, Any]:
    """Return a shallow copy of the active series config (non-Kin mints)."""
    return _copy_series(CURRENT_SERIES)


def kin_series() -> dict[str, Any]:
    """Series config for player-created Kin."""
    return _copy_series(KIN_SERIES)


def current_id_token() -> str:
    return str(CURRENT_SERIES["idToken"])


def kin_id_token() -> str:
    return str(KIN_SERIES["idToken"])


def current_series_key() -> str:
    return str(CURRENT_SERIES["seriesKey"])


def kin_series_key() -> str:
    return str(KIN_SERIES["seriesKey"])


def current_series_display() -> str:
    return str(CURRENT_SERIES["seriesDisplay"])


def kin_series_display() -> str:
    return str(KIN_SERIES["seriesDisplay"])


def list_series_catalog() -> list[dict[str, str]]:
    """Stable series list for Velora home (key / label / seriesKey)."""
    return [dict(row) for row in SERIES_CATALOG]


def series_filter_matches(design_series: str, series_filter: str) -> bool:
    """True if a design's series label/key matches an index ?series= filter."""
    ds = (design_series or "").strip().lower()
    sf = (series_filter or "").strip().lower()
    if not sf:
        return True
    if not ds:
        return False
    ds_slug = _series_slug(ds)
    sf_slug = _series_slug(sf)
    if ds_slug.endswith("_series"):
        ds_slug = ds_slug[: -len("_series")]
    if sf_slug.endswith("_series"):
        sf_slug = sf_slug[: -len("_series")]
    return sf_slug == ds_slug or sf_slug in ds or ds_slug in sf_slug
