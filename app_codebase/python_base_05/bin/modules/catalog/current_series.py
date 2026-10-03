"""Current catalog series for newly minted designs (and Kin series).

Launch static Arcori: Genesis / SER001 (`ANM-TIG-SER001-…`, etc.).

Player-created Kin uses **KIN_SERIES** (Kin / SER005) — not Genesis.
Kin **templates** (Flutter `kins.json` / Lottie bases) are claim-only and must
not appear in Velora browse.

Series browse list + master circulation switch: `data/03_series.json`
(hot-reloaded via catalog_loader). A design circulates only when its series is
`active: true` there AND its own `worldState` is Active.

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

from modules.catalog import catalog_loader as loader

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


def _normalize_series_slug(value: str) -> str:
    """Collapse 'Genesis Series' / 'genesis' / 'Genesis' to a stable slug."""
    slug = _series_slug(value)
    if slug.endswith("_series"):
        slug = slug[: -len("_series")]
    return slug


def media_folder_for_series(series_key: str) -> str:
    """Map series key/display slug to assets/images/arcori/<folder>."""
    slug = _normalize_series_slug(series_key)
    if slug in SERIES_MEDIA_FOLDERS:
        return SERIES_MEDIA_FOLDERS[slug]
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


def _load_series_rows() -> list[dict[str, Any]]:
    """Raw series entries from 03_series.json (mtime-cached)."""
    try:
        data = loader.load_meta("series")
    except (OSError, KeyError, TypeError, ValueError):
        return []
    if not isinstance(data, dict):
        return []
    rows = data.get("series")
    if not isinstance(rows, list):
        return []
    out: list[dict[str, Any]] = []
    for row in rows:
        if isinstance(row, dict):
            out.append(row)
    return out


def list_series_catalog(*, active_only: bool = False) -> list[dict[str, str]]:
    """Series list for Velora home (key / label / seriesKey).

    When ``active_only`` is True, only rows with ``active: true`` are returned
    (master series circulation switch).
    """
    out: list[dict[str, str]] = []
    for row in _load_series_rows():
        if active_only and not bool(row.get("active")):
            continue
        key = str(row.get("key") or "").strip()
        label = str(row.get("label") or "").strip()
        series_key = str(row.get("seriesKey") or label or key).strip()
        if not key and not series_key:
            continue
        out.append(
            {
                "key": key or _normalize_series_slug(series_key),
                "label": label or series_key or key,
                "seriesKey": series_key or label or key,
            }
        )
    return out


def series_is_active(series_key: str) -> bool:
    """True when 03_series.json lists this series with active: true.

    Missing / unknown series keys are inactive (fail closed).
    """
    needle = _normalize_series_slug(series_key or "")
    if not needle:
        return False
    for row in _load_series_rows():
        candidates = (
            str(row.get("key") or ""),
            str(row.get("seriesKey") or ""),
            str(row.get("label") or ""),
        )
        for cand in candidates:
            if not cand.strip():
                continue
            if _normalize_series_slug(cand) == needle:
                return bool(row.get("active"))
        media = str(row.get("mediaFolder") or "").strip().lower()
        if media and needle == media:
            return bool(row.get("active"))
        # "001_genesis" → compare trailing slug
        if media and "_" in media:
            folder_slug = media.split("_", 1)[-1]
            if needle == folder_slug:
                return bool(row.get("active"))
    return False


def resolve_design_series_key(
    design: dict[str, Any] | None,
    *,
    series_key: str | None = None,
    internal_id: str | None = None,
) -> str:
    """Stable series key for a design (Kin always Kin, even if JSON says Genesis)."""
    if series_key and str(series_key).strip():
        sk = str(series_key).strip()
        # Explicit Kin override still wins when caller knows.
        if _normalize_series_slug(sk) == "kin":
            return kin_series_key()
    iid = (internal_id or "").strip()
    if not iid and isinstance(design, dict):
        iid = str(design.get("internalId") or "").strip()
    theme_code = ""
    theme = ""
    if isinstance(design, dict):
        theme_code = str(design.get("themeCode") or "").strip().upper()
        theme = str(design.get("theme") or "").strip().lower()
    is_kin = (
        theme_code == "KIN"
        or theme == "kin"
        or iid.upper().startswith("KIN-")
    )
    if is_kin:
        return kin_series_key()
    if series_key and str(series_key).strip():
        return str(series_key).strip()
    if isinstance(design, dict):
        for field in ("seriesKey", "series"):
            raw = design.get(field)
            if isinstance(raw, str) and raw.strip():
                return raw.strip()
    if iid:
        from modules.catalog.catalog_ids import parse_design_id, series_name_for_ser_number

        parsed = parse_design_id(iid)
        if parsed is not None:
            return series_name_for_ser_number(parsed.series_number)
    return ""


def design_series_is_active(
    design: dict[str, Any] | None,
    *,
    series_key: str | None = None,
    internal_id: str | None = None,
) -> bool:
    """Master series switch for a design document / id."""
    resolved = resolve_design_series_key(
        design,
        series_key=series_key,
        internal_id=internal_id,
    )
    return series_is_active(resolved)


def series_filter_matches(design_series: str, series_filter: str) -> bool:
    """True if a design's series label/key matches an index ?series= filter."""
    ds = (design_series or "").strip().lower()
    sf = (series_filter or "").strip().lower()
    if not sf:
        return True
    if not ds:
        return False
    ds_slug = _normalize_series_slug(ds)
    sf_slug = _normalize_series_slug(sf)
    return sf_slug == ds_slug or sf_slug in ds or ds_slug in sf_slug
