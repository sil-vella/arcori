"""Current catalog series for newly minted designs (Kin, future generators).

Launch: Genesis / SER001 — same id token as static catalog Arcori
(`ANM-TIG-SER001-0001`, etc.).

To open a new series for all future minted designs, change only this module
(and add the matching `data/series/<folder>/` catalog tree when authoring
static designs). Do not scatter series tokens in claim/mint call sites.

Note: `idToken` is the series marker in `internalId` (SER000 Creation,
SER001 Genesis, SER002 Pioneers, SER003 Foundations, SER004 Civilizations). It is not the
generation number — generation stays on `generation.number` / `roman`
(still I / 1 at launch).

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
}

# --- bump here when opening the next series for newly minted Arcori/Kin ---
CURRENT_SERIES: dict[str, Any] = {
    "seriesKey": "Genesis",
    "seriesDisplay": "Genesis Series",
    "idToken": "SER001",
    "folder": "genesis",
    "mediaFolder": SERIES_MEDIA_FOLDERS["genesis"],
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


def current_series() -> dict[str, Any]:
    """Return a shallow copy of the active series config."""
    cfg = CURRENT_SERIES
    return {
        "seriesKey": cfg["seriesKey"],
        "seriesDisplay": cfg["seriesDisplay"],
        "idToken": cfg["idToken"],
        "folder": cfg["folder"],
        "mediaFolder": cfg.get("mediaFolder") or media_folder_for_series(cfg["seriesKey"]),
        "generation": dict(cfg["generation"]),
        "legacy": dict(cfg["legacy"]),
    }


def current_id_token() -> str:
    return str(CURRENT_SERIES["idToken"])


def current_series_key() -> str:
    return str(CURRENT_SERIES["seriesKey"])


def current_series_display() -> str:
    return str(CURRENT_SERIES["seriesDisplay"])
