"""Match-time Arcori selection from 04_selection_weights.json.

After seats exist, pick one design per seat from that player's accessible list
(still in circulation). Prefer weighted score (printedRarity × region standing);
if weights fail or the weighted pool is empty, random among that player's
circulating candidates only. Never pick from the global circulating catalog.

Candidate ids come from DB (`player_design_access` or seat `candidateIds`).
Design docs resolve via catalog `get_design` (static JSON + player Kin files/DB)
so claimed Kin and other player-minted circulating stock stay in the pool.
Trove / closed mints are not access and are not selectable.
"""

from __future__ import annotations

import json
import random
from collections import Counter
from typing import Any

from core.errors.app_error import AppError
from core.utils.dev_logger import customlog
from modules.catalog import catalog_loader as loader
from modules.catalog.catalog_errors import INVALID_QUERY, NOT_FOUND
from modules.catalog.catalog_service import get_design
from modules.catalog.velora_media import arena_image_url

LOGGING_SWITCH = True

SOURCE_WEIGHTED = "weighted"
SOURCE_RANDOM_FALLBACK = "random_fallback"


def _is_circulating(design: dict[str, Any] | None) -> bool:
    if not isinstance(design, dict):
        return False
    world = str(design.get("worldState") or "").strip().lower()
    return not world or world == "active"


def _resolve_design(design_id: str) -> dict[str, Any] | None:
    """Static catalog or player Kin (design file / player_kin.catalog_design)."""
    iid = (design_id or "").strip()
    if not iid:
        return None
    try:
        design = get_design(iid)
    except AppError as err:
        if err.code not in (NOT_FOUND.code, INVALID_QUERY.code) and LOGGING_SWITCH:
            customlog(f"catalog_select: resolve fail id={iid} code={err.code}")
        return None
    return design if isinstance(design, dict) else None


def _filter_circulating_candidates(candidate_ids: list[str]) -> list[str]:
    """Keep access ids that still resolve to an Active (circulating) design."""
    out: list[str] = []
    seen: set[str] = set()
    for design_id in candidate_ids:
        iid = str(design_id or "").strip()
        if not iid or iid in seen:
            continue
        found = _resolve_design(iid)
        if not _is_circulating(found):
            continue
        seen.add(iid)
        out.append(iid)
    return out


def _region_of(design: dict[str, Any] | None) -> str | None:
    if not isinstance(design, dict):
        return None
    loc = design.get("location")
    if not isinstance(loc, dict):
        return None
    code = loc.get("regionCode")
    if code is None:
        return None
    text = str(code).strip()
    return text or None


def _load_weights_table() -> tuple[dict[str, Any] | None, str | None]:
    """Return (table, fail_reason). fail_reason set when unusable."""
    try:
        raw = loader.load_meta("selection_weights")
    except (OSError, json.JSONDecodeError, KeyError, TypeError, ValueError) as exc:
        return None, f"weights_load_failed:{exc}"
    if not isinstance(raw, dict):
        return None, "weights_not_object"
    rarity = raw.get("printedRarity")
    region = raw.get("regionStanding")
    if not isinstance(rarity, dict) or not isinstance(region, dict):
        return None, "weights_shape_invalid"
    weights = rarity.get("weights")
    pairs = region.get("pairs")
    if not isinstance(weights, dict) or not isinstance(pairs, dict):
        return None, "weights_shape_invalid"
    return raw, None


def _rarity_weight(table: dict[str, Any], design: dict[str, Any]) -> float | None:
    rarity_block = table["printedRarity"]
    weights = rarity_block["weights"]
    printed = design.get("printedRarity")
    if printed is None or str(printed).strip() == "":
        missing = rarity_block.get("missingPrintedRarity", 3.0)
        try:
            return float(missing)
        except (TypeError, ValueError):
            return 3.0
    key = str(printed).strip()
    if key not in weights:
        missing = rarity_block.get("missingPrintedRarity", 3.0)
        try:
            return float(missing)
        except (TypeError, ValueError):
            return 3.0
    raw = weights[key]
    if raw is None:
        return None
    try:
        return float(raw)
    except (TypeError, ValueError):
        return None


def _region_multiplier(
    table: dict[str, Any],
    candidate_region: str | None,
    seated_regions: list[str],
) -> float:
    region_block = table["regionStanding"]
    if not seated_regions:
        try:
            return float(region_block.get("noSeatedRegionsMultiplier", 1.0))
        except (TypeError, ValueError):
            return 1.0
    if not candidate_region:
        try:
            return float(region_block.get("unknownPairMultiplier", 1.0))
        except (TypeError, ValueError):
            return 1.0

    pairs = region_block.get("pairs")
    if not isinstance(pairs, dict):
        return 1.0

    unknown = 1.0
    try:
        unknown = float(region_block.get("unknownPairMultiplier", 1.0))
    except (TypeError, ValueError):
        unknown = 1.0
    same = 1.0
    try:
        same = float(region_block.get("sameRegionMultiplier", 1.0))
    except (TypeError, ValueError):
        same = 1.0

    multipliers: list[float] = []
    row = pairs.get(candidate_region)
    for seated in seated_regions:
        if seated == candidate_region:
            multipliers.append(same)
            continue
        if not isinstance(row, dict):
            multipliers.append(unknown)
            continue
        entry = row.get(seated)
        if not isinstance(entry, dict):
            multipliers.append(unknown)
            continue
        try:
            multipliers.append(float(entry.get("multiplier", unknown)))
        except (TypeError, ValueError):
            multipliers.append(unknown)

    if not multipliers:
        return 1.0
    return max(multipliers)


def _weighted_pick(ids: list[str], weights: list[float]) -> str:
    total = sum(weights)
    if total <= 0:
        return random.choice(ids)
    r = random.random() * total
    acc = 0.0
    for design_id, weight in zip(ids, weights):
        acc += weight
        if r <= acc:
            return design_id
    return ids[-1]


def _pick_one(
    *,
    user_id: str,
    seat_index: int,
    candidates: list[str],
    table: dict[str, Any] | None,
    table_fail: str | None,
    seated_regions: list[str],
) -> dict[str, Any]:
    # candidates must already be that player's circulating access only.
    if not candidates:
        if LOGGING_SWITCH:
            customlog(
                f"catalog_select: seat={seat_index} user={user_id} "
                f"candidates=0 source={SOURCE_RANDOM_FALLBACK} "
                f"reason=empty_player_access"
            )
        return {
            "userId": user_id,
            "arcoriId": "",
            "source": SOURCE_RANDOM_FALLBACK,
            "reason": "empty_player_access",
        }

    if table is None:
        chosen = random.choice(candidates)
        if LOGGING_SWITCH:
            customlog(
                f"catalog_select: seat={seat_index} user={user_id} "
                f"candidates={len(candidates)} chosen={chosen} "
                f"source={SOURCE_RANDOM_FALLBACK} reason={table_fail or 'no_table'} "
                f"seated_regions={seated_regions}"
            )
        return {
            "userId": user_id,
            "arcoriId": chosen,
            "source": SOURCE_RANDOM_FALLBACK,
            "reason": table_fail or "no_table",
        }

    pool_ids: list[str] = []
    pool_weights: list[float] = []
    for design_id in candidates:
        found = _resolve_design(design_id)
        if found is None or not _is_circulating(found):
            continue
        rarity_w = _rarity_weight(table, found)
        if rarity_w is None or rarity_w <= 0:
            continue
        region = _region_of(found)
        mult = _region_multiplier(table, region, seated_regions)
        score = rarity_w * mult
        if score <= 0:
            continue
        pool_ids.append(design_id)
        pool_weights.append(score)

    if not pool_ids:
        chosen = random.choice(candidates)
        if LOGGING_SWITCH:
            customlog(
                f"catalog_select: seat={seat_index} user={user_id} "
                f"candidates={len(candidates)} chosen={chosen} "
                f"source={SOURCE_RANDOM_FALLBACK} reason=empty_weighted_pool "
                f"seated_regions={seated_regions}"
            )
        return {
            "userId": user_id,
            "arcoriId": chosen,
            "source": SOURCE_RANDOM_FALLBACK,
            "reason": "empty_weighted_pool",
        }

    chosen = _weighted_pick(pool_ids, pool_weights)
    chosen_weight = pool_weights[pool_ids.index(chosen)]
    if LOGGING_SWITCH:
        customlog(
            f"catalog_select: seat={seat_index} user={user_id} "
            f"candidates={len(candidates)} pool={len(pool_ids)} "
            f"ids={','.join(pool_ids)} "
            f"chosen={chosen} weight={chosen_weight:.4f} "
            f"source={SOURCE_WEIGHTED} seated_regions={seated_regions}"
        )
    return {
        "userId": user_id,
        "arcoriId": chosen,
        "source": SOURCE_WEIGHTED,
        "weight": chosen_weight,
    }


def select_for_seats(seats: list[dict[str, Any]]) -> dict[str, Any]:
    """Pick one Arcori per seat in order. Returns {selections: [...]}.

    Already-chosen design ids are excluded from later seats so no two seats
    share the same Arcori in one match.
    """
    if not isinstance(seats, list) or not seats:
        raise AppError(INVALID_QUERY, message="seats must be a non-empty list")

    table, table_fail = _load_weights_table()
    if table_fail and LOGGING_SWITCH:
        customlog(f"catalog_select: weights unavailable reason={table_fail}")

    selections: list[dict[str, Any]] = []
    seated_regions: list[str] = []
    taken_ids: set[str] = set()

    for index, raw in enumerate(seats):
        if not isinstance(raw, dict):
            raise AppError(INVALID_QUERY, message="each seat must be an object")
        user_id = str(raw.get("userId") or "").strip()
        if not user_id:
            raise AppError(INVALID_QUERY, message="seat.userId required")

        candidates: list[str] = []
        raw_candidates = raw.get("candidateIds")
        if raw_candidates is not None:
            if not isinstance(raw_candidates, list):
                raise AppError(INVALID_QUERY, message="candidateIds must be a list")
            seen: set[str] = set()
            for item in raw_candidates:
                design_id = str(item or "").strip()
                if not design_id or design_id in seen:
                    continue
                seen.add(design_id)
                candidates.append(design_id)
        else:
            # Deferred import: avoid catalog → avari repository coupling at module load.
            from modules.avari.avari_service import list_design_access_ids

            candidates = list_design_access_ids(user_id)

        candidates = _filter_circulating_candidates(candidates)
        if taken_ids:
            candidates = [c for c in candidates if c not in taken_ids]

        pick = _pick_one(
            user_id=user_id,
            seat_index=index,
            candidates=candidates,
            table=table,
            table_fail=table_fail,
            seated_regions=list(seated_regions),
        )
        selections.append(pick)

        chosen_id = str(pick.get("arcoriId") or "").strip()
        if chosen_id:
            taken_ids.add(chosen_id)
            design = _resolve_design(chosen_id)
            region = _region_of(design)
            if region:
                seated_regions.append(region)

    return {"selections": selections}


SOURCE_MAJORITY = "majority"
SOURCE_RANDOM_REGION = "random_region"
SOURCE_GATHERER_WEIGHTED = "gatherer_weighted"
SOURCE_GATHERER_RANDOM = "gatherer_random"


def _is_playable_match_arcori(design: dict[str, Any]) -> bool:
    """Circulating non-slammer / non-Kin catalog design."""
    if not _is_circulating(design):
        return False
    theme_code = str(design.get("themeCode") or "").strip().upper()
    if theme_code in {"SLM", "KIN"}:
        return False
    dtype = str(design.get("type") or "").strip().lower()
    if dtype in {"slammer"}:
        return False
    return True


def _circulating_ids_in_region(region_code: str) -> list[str]:
    """Static catalog ids in region (any series), playable match stock only."""
    code = (region_code or "").strip().upper()
    if not code:
        return []
    out: list[str] = []
    seen: set[str] = set()
    try:
        docs = loader.list_theme_documents()
    except (OSError, json.JSONDecodeError, KeyError, TypeError, ValueError):
        return []
    for doc in docs:
        if not isinstance(doc, dict):
            continue
        doc_theme = str(doc.get("themeCode") or "").strip().upper()
        if doc_theme in {"SLM", "KIN"}:
            continue
        designs = doc.get("designs")
        if not isinstance(designs, list):
            continue
        for design in designs:
            if not isinstance(design, dict):
                continue
            if not _is_playable_match_arcori(design):
                continue
            if _region_of(design) != code:
                continue
            iid = str(design.get("internalId") or "").strip()
            if not iid or iid in seen:
                continue
            seen.add(iid)
            out.append(iid)
    return out


def select_gatherer_for_region(
    region_code: str,
    *,
    exclude_ids: list[str] | None = None,
    rng: random.Random | None = None,
) -> dict[str, Any] | None:
    """Weighted Gatherer from circulating catalog designs in ``region_code``.

    Uses ``04_selection_weights`` printedRarity only. Excludes seated player
    ids, slammers, and Kin. Returns None if the pool is empty.
    """
    picker = rng or random.Random()
    excluded = {
        str(x or "").strip()
        for x in (exclude_ids or [])
        if str(x or "").strip()
    }
    pool = [iid for iid in _circulating_ids_in_region(region_code) if iid not in excluded]
    if not pool:
        if LOGGING_SWITCH:
            customlog(
                f"catalog_select: gatherer empty region={region_code} "
                f"excluded={len(excluded)}"
            )
        return None

    table, table_fail = _load_weights_table()
    if table is None:
        chosen = picker.choice(pool)
        if LOGGING_SWITCH:
            customlog(
                f"catalog_select: gatherer region={region_code} "
                f"chosen={chosen} source={SOURCE_GATHERER_RANDOM} "
                f"reason={table_fail or 'no_table'} pool={len(pool)}"
            )
        return {
            "gathererArcoriId": chosen,
            "regionCode": region_code.strip().upper(),
            "source": SOURCE_GATHERER_RANDOM,
            "reason": table_fail or "no_table",
        }

    pool_ids: list[str] = []
    pool_weights: list[float] = []
    for design_id in pool:
        found = _resolve_design(design_id)
        if found is None or not _is_playable_match_arcori(found):
            continue
        rarity_w = _rarity_weight(table, found)
        if rarity_w is None or rarity_w <= 0:
            continue
        pool_ids.append(design_id)
        pool_weights.append(rarity_w)

    if not pool_ids:
        chosen = picker.choice(pool)
        if LOGGING_SWITCH:
            customlog(
                f"catalog_select: gatherer region={region_code} "
                f"chosen={chosen} source={SOURCE_GATHERER_RANDOM} "
                f"reason=empty_weighted_pool pool={len(pool)}"
            )
        return {
            "gathererArcoriId": chosen,
            "regionCode": region_code.strip().upper(),
            "source": SOURCE_GATHERER_RANDOM,
            "reason": "empty_weighted_pool",
        }

    # Prefer picker.choices when available for seeded tests; else _weighted_pick.
    total = sum(pool_weights)
    if total <= 0:
        chosen = picker.choice(pool_ids)
    else:
        # Manual cumulative with picker.random for rng control.
        r = picker.random() * total
        acc = 0.0
        chosen = pool_ids[-1]
        for design_id, weight in zip(pool_ids, pool_weights):
            acc += weight
            if r <= acc:
                chosen = design_id
                break
    chosen_weight = pool_weights[pool_ids.index(chosen)]
    if LOGGING_SWITCH:
        customlog(
            f"catalog_select: gatherer region={region_code} "
            f"chosen={chosen} weight={chosen_weight:.4f} "
            f"source={SOURCE_GATHERER_WEIGHTED} pool={len(pool_ids)}"
        )
    return {
        "gathererArcoriId": chosen,
        "regionCode": region_code.strip().upper(),
        "source": SOURCE_GATHERER_WEIGHTED,
        "weight": chosen_weight,
    }


def _arenas_by_region() -> dict[str, list[dict[str, Any]]]:
    """regionCode → arena dicts with arenaId, name, regionCode, slug, imageUrl."""
    try:
        meta = loader.load_meta("regions")
    except (OSError, json.JSONDecodeError, KeyError, TypeError, ValueError):
        return {}
    if not isinstance(meta, dict):
        return {}
    out: dict[str, list[dict[str, Any]]] = {}
    for region in meta.get("regions") or []:
        if not isinstance(region, dict):
            continue
        code = str(region.get("regionCode") or "").strip()
        if not code:
            continue
        slug = str(region.get("slug") or "").strip() or code.lower()
        arenas: list[dict[str, Any]] = []
        for raw in region.get("arenas") or []:
            if not isinstance(raw, dict):
                continue
            arena_id = str(raw.get("arenaId") or "").strip()
            if not arena_id:
                continue
            image_file = str(raw.get("imageFile") or "").strip() or None
            arenas.append(
                {
                    "arenaId": arena_id,
                    "name": str(raw.get("name") or arena_id),
                    "regionCode": code,
                    "slug": slug,
                    "imageUrl": arena_image_url(
                        slug=slug,
                        arena_id=arena_id,
                        image_file=image_file,
                    ),
                }
            )
        if arenas:
            out[code] = arenas
    return out


def select_arena_for_arcori_ids(
    arcori_ids: list[str],
    *,
    rng: random.Random | None = None,
) -> dict[str, Any]:
    """Pick an arena from seated Arcori regions.

    2+ seats in the same region → random arena in that region.
    Otherwise → random catalog region that has arenas, then a random arena.
    """
    if not isinstance(arcori_ids, list):
        raise AppError(INVALID_QUERY, message="arcoriIds must be a list")

    picker = rng or random.Random()
    by_region = _arenas_by_region()
    if not by_region:
        raise AppError(INVALID_QUERY, message="no arenas in catalog")

    seated: list[str] = []
    seated_ids_for_exclude: list[str] = []
    seen_ids: set[str] = set()
    for raw_id in arcori_ids:
        iid = str(raw_id or "").strip()
        if not iid:
            continue
        if iid not in seen_ids:
            seen_ids.add(iid)
            seated_ids_for_exclude.append(iid)
        design = _resolve_design(iid)
        region = _region_of(design)
        if region:
            seated.append(region)

    counts = Counter(seated)
    majority = [code for code, n in counts.items() if n >= 2 and code in by_region]
    if majority:
        chosen_region = picker.choice(majority)
        source = SOURCE_MAJORITY
    else:
        chosen_region = picker.choice(list(by_region.keys()))
        source = SOURCE_RANDOM_REGION

    arenas = by_region.get(chosen_region) or []
    if not arenas:
        arenas = [arena for pool in by_region.values() for arena in pool]
        source = SOURCE_RANDOM_REGION
        chosen_region = arenas[0]["regionCode"] if arenas else chosen_region
    if not arenas:
        raise AppError(INVALID_QUERY, message="no arenas in catalog")

    arena = picker.choice(arenas)
    region_code = str(arena["regionCode"])
    gatherer = select_gatherer_for_region(
        region_code,
        exclude_ids=seated_ids_for_exclude,
        rng=picker,
    )
    if LOGGING_SWITCH:
        customlog(
            f"catalog_select: select_arena source={source} "
            f"region={region_code} arenaId={arena['arenaId']} "
            f"seated={seated} majority={majority} "
            f"gatherer={(gatherer or {}).get('gathererArcoriId')}"
        )
    out: dict[str, Any] = {
        "arenaId": arena["arenaId"],
        "regionCode": region_code,
        "name": arena["name"],
        "imageUrl": arena["imageUrl"],
        "source": source,
    }
    if gatherer and gatherer.get("gathererArcoriId"):
        out["gathererArcoriId"] = gatherer["gathererArcoriId"]
        out["gathererSource"] = gatherer.get("source")
    return out
