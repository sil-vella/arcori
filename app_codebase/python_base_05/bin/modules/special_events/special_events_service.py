"""Special events service — catalog, match rules, eligibility, arena, credit."""

from __future__ import annotations

import random
from datetime import datetime, timezone
from typing import Any

from sqlalchemy.orm import Session

from core.utils.dev_logger import customlog
from core.utils.media_fields import media_for_client
from modules.avari.gold_economy import DEFAULT_MATCH_FEE_FRAGMENTS
from modules.special_events import special_events_repository as repo
from modules.special_events.special_events_loader import (
    catalog_revision,
    client_event_row,
    event_by_id,
    list_events,
)
from modules.special_events.special_events_types import (
    ARCORI_SOURCE_ACTIVE_WINDOWS,
    ARCORI_SOURCE_CIRCULATION,
    ARCORI_SOURCE_EVENT_ROSTER,
    ARCORI_SOURCE_INTERSECT,
    ARCORI_SOURCE_OWN,
    ARENA_MODE_FIXED_ARENA,
    ARENA_MODE_FIXED_REGION,
    ARENA_MODE_SEATED_REGIONS,
    MATCH_CREDIT_ANY_FINISH,
    MATCH_CREDIT_FLIPS_MIN,
    MATCH_CREDIT_WIN,
    SLAMMER_MODE_ANY,
    SLAMMER_MODE_DESIGN_IDS,
    SLAMMER_MODE_TYPES,
)

LOGGING_SWITCH = True


def _parse_iso(raw: str | None) -> datetime | None:
    if not raw:
        return None
    text = str(raw).strip()
    if not text:
        return None
    try:
        if text.endswith("Z"):
            text = text[:-1] + "+00:00"
        return datetime.fromisoformat(text)
    except ValueError:
        return None


def _schedule_open(ev: dict[str, Any], *, now: datetime | None = None) -> bool:
    schedule = ev.get("schedule") or {}
    starts = _parse_iso(schedule.get("starts_at"))
    ends = _parse_iso(schedule.get("ends_at"))
    clock = now or datetime.now(timezone.utc)
    if starts is not None and clock < starts:
        return False
    if ends is not None and clock > ends:
        return False
    return True


def should_credit_match(
    ev: dict[str, Any],
    *,
    won: bool,
    flips: int,
) -> bool:
    matches = ev.get("matches") or {}
    credit = str(matches.get("credit") or MATCH_CREDIT_ANY_FINISH).strip().lower()
    if credit == MATCH_CREDIT_WIN:
        return bool(won)
    if credit == MATCH_CREDIT_FLIPS_MIN:
        params = matches.get("credit_params") or {}
        try:
            minimum = max(1, int(params.get("min") or 1))
        except (TypeError, ValueError):
            minimum = 1
        return int(flips) >= minimum
    return True


def resolve_event_fee_fragments(event_id: str | None) -> int | None:
    """Return override fee or None to use default online fee."""
    ev = event_by_id(event_id or "")
    if ev is None:
        return None
    fee = (ev.get("match") or {}).get("fee_fragments")
    if fee is None:
        return None
    try:
        return max(0, int(fee))
    except (TypeError, ValueError):
        return None


def match_fee_for_event(event_id: str | None) -> int:
    override = resolve_event_fee_fragments(event_id)
    if override is not None:
        return override
    return DEFAULT_MATCH_FEE_FRAGMENTS


def resolve_event_arena(ev: dict[str, Any]) -> dict[str, Any] | None:
    """Pre-resolve arena for fixed modes. seated_regions → None (Dart calls select_arena)."""
    from modules.catalog.catalog_select import _arenas_by_region

    arena = ev.get("arena") or {}
    mode = str(arena.get("mode") or ARENA_MODE_SEATED_REGIONS).strip()
    media = ev.get("media") if isinstance(ev.get("media"), dict) else {}
    bg = media.get("special_arena_background") if isinstance(media, dict) else None
    bg_url = ""
    if isinstance(bg, dict):
        bg_url = str(bg.get("value") or "").strip()

    by_region = _arenas_by_region()
    picker = random.Random()

    def _pack(arena_row: dict[str, Any], *, source: str) -> dict[str, Any]:
        image = bg_url or str(arena_row.get("imageUrl") or "").strip()
        return {
            "arenaId": arena_row.get("arenaId"),
            "regionCode": arena_row.get("regionCode"),
            "name": arena_row.get("name"),
            "imageUrl": image,
            "source": source,
            "useSpecialBackground": bool(bg_url),
        }

    if mode == ARENA_MODE_FIXED_ARENA:
        aid = str(arena.get("arena_id") or "").strip()
        for rows in by_region.values():
            for row in rows:
                if str(row.get("arenaId") or "") == aid:
                    return _pack(row, source="event_fixed_arena")
        if bg_url:
            return {
                "arenaId": aid or "event_custom",
                "regionCode": arena.get("region_code"),
                "name": ev.get("name") or "Special Event",
                "imageUrl": bg_url,
                "source": "event_media",
                "useSpecialBackground": True,
            }
        return None

    if mode == ARENA_MODE_FIXED_REGION:
        region = str(arena.get("region_code") or "").strip()
        rows = by_region.get(region) or []
        if rows:
            return _pack(picker.choice(rows), source="event_fixed_region")
        if bg_url:
            return {
                "arenaId": "event_region",
                "regionCode": region or None,
                "name": ev.get("name") or "Special Event",
                "imageUrl": bg_url,
                "source": "event_media",
                "useSpecialBackground": True,
            }
        return None

    # seated_regions — only inject media override hint
    if bg_url:
        return {
            "arenaId": None,
            "regionCode": None,
            "name": None,
            "imageUrl": bg_url,
            "source": "event_media_override",
            "useSpecialBackground": True,
            "deferSelectArena": True,
        }
    return None


def _design_matches_filters(design_id: str, arcori: dict[str, Any]) -> bool:
    from modules.catalog.catalog_select import _region_of, _resolve_design

    series_ids = set(arcori.get("series_ids") or [])
    gens = set(int(x) for x in (arcori.get("generation_numbers") or []))
    regions = set(str(r).strip() for r in (arcori.get("region_codes") or []) if str(r).strip())
    if not series_ids and not gens and not regions:
        return True
    design = _resolve_design(design_id)
    if design is None:
        return False
    if regions:
        reg = _region_of(design)
        if not reg or reg not in regions:
            return False
    if series_ids:
        series_val: Any = design.get("seriesId") or design.get("series_id")
        if series_val is None:
            series_obj = design.get("series")
            if isinstance(series_obj, dict):
                series_val = series_obj.get("id")
            else:
                series_val = series_obj
        if str(series_val or "").strip() not in series_ids:
            return False
    if gens:
        gen = design.get("generationNumber") or design.get("generation_number") or design.get("generation")
        try:
            if int(gen) not in gens:
                return False
        except (TypeError, ValueError):
            return False
    return True


def build_candidate_ids_for_user(
    session: Session,
    *,
    user_id: str,
    event: dict[str, Any],
) -> list[str] | None:
    """
    Return candidateIds for select_for_seats, or None to use default access pool
    (circulation without filters).
    """
    from math import ceil

    from modules.avari.avari_repository import mastery_points_by_design
    from modules.avari.avari_service import (
        list_design_access_ids,
        mint_reach_or_series_default,
    )
    from modules.catalog.catalog_select import _resolve_design
    from modules.players.players_service import is_ai_user

    arcori = event.get("arcori") or {}
    source = str(arcori.get("source") or ARCORI_SOURCE_CIRCULATION).strip()
    roster = list(arcori.get("design_ids") or event.get("design_ids") or [])
    access = list_design_access_ids(user_id)
    ratio_raw = arcori.get("min_mastery_ratio")
    try:
        min_ratio = float(ratio_raw) if ratio_raw is not None else None
    except (TypeError, ValueError):
        min_ratio = None
    if min_ratio is not None and min_ratio <= 0:
        min_ratio = None

    if source == ARCORI_SOURCE_ACTIVE_WINDOWS:
        from modules.legacy import legacy_repository as legacy_repo

        open_ids: list[str] = []
        seen_open: set[str] = set()
        for life in legacy_repo.list_open_preservation_windows(session):
            design_id = str(getattr(life, "design_id", "") or "").strip()
            if not design_id or design_id in seen_open:
                continue
            seen_open.add(design_id)
            open_ids.append(design_id)
        if is_ai_user(user_id):
            # Live global open-window roster; empty → default access (starters).
            if not open_ids:
                return None
            base = open_ids
        else:
            base = [d for d in access if d in seen_open]
    elif source == ARCORI_SOURCE_CIRCULATION:
        has_geo_filters = bool(
            arcori.get("series_ids")
            or arcori.get("generation_numbers")
            or arcori.get("region_codes")
        )
        # Bare circulation (no filters, no ratio) → default full access pool.
        if not has_geo_filters and min_ratio is None:
            return None
        base = access
    elif source == ARCORI_SOURCE_OWN:
        base = access
    elif source == ARCORI_SOURCE_EVENT_ROSTER:
        base = roster
    elif source == ARCORI_SOURCE_INTERSECT:
        roster_set = set(roster)
        base = [d for d in access if d in roster_set] if roster_set else access
    else:
        base = access

    filtered = [d for d in base if _design_matches_filters(d, arcori)]

    if min_ratio is not None:
        mastery_by = mastery_points_by_design(session, user_id)
        ratio_kept: list[str] = []
        for did in filtered:
            design = _resolve_design(did)
            reach = mint_reach_or_series_default(design)
            need = int(ceil(min_ratio * reach))
            pts = int(mastery_by.get(did) or 0)
            if pts >= need:
                ratio_kept.append(did)
        filtered = ratio_kept
        if not filtered and is_ai_user(user_id):
            # AI with no high-mastery designs → default access (starters).
            return None

    return filtered


def evaluate_eligibility(
    session: Session,
    *,
    user_id: str,
    event: dict[str, Any],
    mastery_value: float,
    titles: list[str] | None = None,
    equipped_slammer_id: str | None = None,
) -> dict[str, Any]:
    """Return { eligible, blockedReason?, progress fields }. """
    eid = str(event.get("id") or "")
    progress = repo.progress_snapshot(session, user_id=user_id, event_id=eid)
    matches = event.get("matches") or {}
    required = int(matches.get("required") or 1)
    credited = int(progress.get("matchesCredited") or 0)

    if not event.get("active", True):
        return {**progress, "matchesRequired": required, "eligible": False, "blockedReason": "inactive"}
    if not _schedule_open(event):
        return {**progress, "matchesRequired": required, "eligible": False, "blockedReason": "schedule"}
    if credited >= required and not bool(matches.get("allow_replay_after_complete")):
        return {**progress, "matchesRequired": required, "eligible": False, "blockedReason": "complete"}

    elig = event.get("eligibility") or {}
    min_mv = float(elig.get("min_mastery_value") or 0)
    max_mv = elig.get("max_mastery_value")
    if mastery_value < min_mv:
        return {
            **progress,
            "matchesRequired": required,
            "eligible": False,
            "blockedReason": "mastery_low",
        }
    if max_mv is not None:
        try:
            if mastery_value > float(max_mv):
                return {
                    **progress,
                    "matchesRequired": required,
                    "eligible": False,
                    "blockedReason": "mastery_high",
                }
        except (TypeError, ValueError):
            pass

    need_titles = [str(t).strip() for t in (elig.get("required_titles") or []) if str(t).strip()]
    if need_titles:
        have = {str(t).strip() for t in (titles or []) if str(t).strip()}
        if not all(t in have for t in need_titles):
            return {
                **progress,
                "matchesRequired": required,
                "eligible": False,
                "blockedReason": "titles",
            }

    slammer = elig.get("required_slammer") or {}
    mode = str(slammer.get("mode") or SLAMMER_MODE_ANY).strip()
    sid = (equipped_slammer_id or "").strip()
    if mode == SLAMMER_MODE_DESIGN_IDS:
        allowed = {str(x).strip() for x in (slammer.get("design_ids") or []) if str(x).strip()}
        if allowed and sid not in allowed:
            return {
                **progress,
                "matchesRequired": required,
                "eligible": False,
                "blockedReason": "slammer",
            }
    elif mode == SLAMMER_MODE_TYPES:
        # Soft: types list present but type lookup not wired → require equipped id only.
        types = [str(x).strip() for x in (slammer.get("types") or []) if str(x).strip()]
        if types and not sid:
            return {
                **progress,
                "matchesRequired": required,
                "eligible": False,
                "blockedReason": "slammer",
            }

    return {
        **progress,
        "matchesRequired": required,
        "eligible": True,
        "blockedReason": None,
    }


def get_match_rules(event_id: str) -> dict[str, Any]:
    """Compact rules for Dart matchmaking / match start."""
    ev = event_by_id(event_id)
    if ev is None:
        return {}
    mm = ev.get("matchmaking") or {}
    match = ev.get("match") or {}
    arcori = ev.get("arcori") or {}
    arena_resolved = resolve_event_arena(ev)
    fee = match.get("fee_fragments")
    if fee is None:
        fee = DEFAULT_MATCH_FEE_FRAGMENTS
    media_client = media_for_client(ev.get("media") if isinstance(ev.get("media"), dict) else {})
    return {
        "eventId": ev.get("id"),
        "subtype": ev.get("subtype") or "",
        "name": ev.get("name"),
        "players": int(mm.get("players") or 3),
        "aiFill": bool(mm.get("ai_fill", True)),
        "fillWindowSec": int(mm.get("fill_window_sec") or 5),
        "rounds": int(match.get("rounds") or 2),
        "feeFragments": int(fee),
        "arcori": {
            "perPlayer": int(arcori.get("per_player") or 1),
            "source": arcori.get("source") or ARCORI_SOURCE_CIRCULATION,
            "seriesIds": list(arcori.get("series_ids") or []),
            "generationNumbers": list(arcori.get("generation_numbers") or []),
            "regionCodes": list(arcori.get("region_codes") or []),
            "designIds": list(arcori.get("design_ids") or []),
        },
        "arena": {
            "mode": (ev.get("arena") or {}).get("mode") or ARENA_MODE_SEATED_REGIONS,
            "regionCode": (ev.get("arena") or {}).get("region_code"),
            "arenaId": (ev.get("arena") or {}).get("arena_id"),
            "resolved": arena_resolved,
        },
        "media": media_client,
        "matchesRequired": int((ev.get("matches") or {}).get("required") or 1),
        "revision": catalog_revision(),
    }


def get_catalog_for_user(
    session: Session,
    *,
    user_id: str,
    mastery_value: float = 0.0,
    titles: list[str] | None = None,
    equipped_slammer_id: str | None = None,
) -> dict[str, Any]:
    events_out: list[dict[str, Any]] = []
    for ev in list_events():
        if not ev.get("active", True):
            continue
        row = client_event_row(ev)
        elig = evaluate_eligibility(
            session,
            user_id=user_id,
            event=ev,
            mastery_value=mastery_value,
            titles=titles,
            equipped_slammer_id=equipped_slammer_id,
        )
        row["progress"] = {
            "matchesCredited": elig.get("matchesCredited") or 0,
            "matchesRequired": elig.get("matchesRequired") or 1,
            "matchesCompleted": elig.get("matchesCompleted") or 0,
            "matchesWon": elig.get("matchesWon") or 0,
            "flips": elig.get("flips") or 0,
            "flippedDesignIds": elig.get("flippedDesignIds") or [],
        }
        row["eligible"] = bool(elig.get("eligible"))
        row["blockedReason"] = elig.get("blockedReason")
        fee = (ev.get("match") or {}).get("fee_fragments")
        row["match"]["feeFragments"] = (
            int(fee) if fee is not None else DEFAULT_MATCH_FEE_FRAGMENTS
        )
        events_out.append(row)
    if LOGGING_SWITCH:
        customlog(f"special_events: catalog user={user_id} n={len(events_out)}")
    return {
        "revision": catalog_revision(),
        "schemaVersion": 2,
        "events": events_out,
    }
