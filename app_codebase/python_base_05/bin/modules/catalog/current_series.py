"""Current catalog series for newly minted designs (Kin, future generators).

Launch: Genesis / GEN001 — same id token as static catalog Arcori
(`ANM-TIG-GEN001-0001`, etc.).

To open a new series for all future minted designs, change only this module
(and add the matching `data/series/<folder>/` catalog tree when authoring
static designs). Do not scatter series tokens in claim/mint call sites.

Note: `idToken` is the series marker in `internalId` (GEN001 Genesis,
GEN002 Pioneers). It is not the generation number — generation stays on
`generation.number` / `roman` (still I / 1 at launch).
"""

from __future__ import annotations

from typing import Any

# --- bump here when opening the next series for newly minted Arcori/Kin ---
CURRENT_SERIES: dict[str, Any] = {
    "seriesKey": "Genesis",
    "seriesDisplay": "Genesis Series",
    "idToken": "GEN001",
    "folder": "genesis",
    "generation": {"roman": "I", "number": 1},
    "legacy": {"preservationRequirement": 500, "closureMilestone": 1000},
}


def current_series() -> dict[str, Any]:
    """Return a shallow copy of the active series config."""
    cfg = CURRENT_SERIES
    return {
        "seriesKey": cfg["seriesKey"],
        "seriesDisplay": cfg["seriesDisplay"],
        "idToken": cfg["idToken"],
        "folder": cfg["folder"],
        "generation": dict(cfg["generation"]),
        "legacy": dict(cfg["legacy"]),
    }


def current_id_token() -> str:
    return str(CURRENT_SERIES["idToken"])


def current_series_key() -> str:
    return str(CURRENT_SERIES["seriesKey"])


def current_series_display() -> str:
    return str(CURRENT_SERIES["seriesDisplay"])
