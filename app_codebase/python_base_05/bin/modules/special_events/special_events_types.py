"""Closed enums for special-event JSON catalog (v2 match rules)."""

from __future__ import annotations

# Legacy unlock-kind labels (achievements still use event_flips / event_arcori_cleared).
UNLOCK_KIND_FLIPS = "flips"
UNLOCK_KIND_ALL_ARCORI = "all_arcori"
UNLOCK_KINDS = frozenset({UNLOCK_KIND_FLIPS, UNLOCK_KIND_ALL_ARCORI})

ARCORI_SOURCE_OWN = "own"
ARCORI_SOURCE_CIRCULATION = "circulation"
ARCORI_SOURCE_EVENT_ROSTER = "event_roster"
ARCORI_SOURCE_INTERSECT = "intersect"
ARCORI_SOURCES = frozenset(
    {
        ARCORI_SOURCE_OWN,
        ARCORI_SOURCE_CIRCULATION,
        ARCORI_SOURCE_EVENT_ROSTER,
        ARCORI_SOURCE_INTERSECT,
    }
)

ARENA_MODE_FIXED_ARENA = "fixed_arena"
ARENA_MODE_FIXED_REGION = "fixed_region"
ARENA_MODE_SEATED_REGIONS = "seated_regions"
ARENA_MODES = frozenset(
    {
        ARENA_MODE_FIXED_ARENA,
        ARENA_MODE_FIXED_REGION,
        ARENA_MODE_SEATED_REGIONS,
    }
)

MATCH_CREDIT_ANY_FINISH = "any_finish"
MATCH_CREDIT_WIN = "win"
MATCH_CREDIT_FLIPS_MIN = "flips_min"
MATCH_CREDITS = frozenset(
    {
        MATCH_CREDIT_ANY_FINISH,
        MATCH_CREDIT_WIN,
        MATCH_CREDIT_FLIPS_MIN,
    }
)

SLAMMER_MODE_ANY = "any"
SLAMMER_MODE_DESIGN_IDS = "design_ids"
SLAMMER_MODE_TYPES = "types"
SLAMMER_MODES = frozenset(
    {
        SLAMMER_MODE_ANY,
        SLAMMER_MODE_DESIGN_IDS,
        SLAMMER_MODE_TYPES,
    }
)

QUEUE_MODE_OPEN = "open"
QUEUE_MODES = frozenset({QUEUE_MODE_OPEN})
