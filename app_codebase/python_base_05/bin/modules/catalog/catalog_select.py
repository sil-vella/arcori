"""Match-time Arcori selection from 04_selection_weights.json.

After seats exist, pick one design per seat from that player's accessible list
(still in circulation). Prefer weighted score (printedRarity × region standing);
if weights fail or the weighted pool is empty, random among that player's
circulating candidates only. Never pick from the global circulating catalog.
"""

from __future__ import annotations

import json
import random
from typing import Any

from core.errors.app_error import AppError
from core.utils.dev_logger import customlog
from modules.catalog import catalog_loader as loader
from modules.catalog.catalog_errors import INVALID_QUERY

LOGGING_SWITCH = True

SOURCE_WEIGHTED = "weighted"
SOURCE_RANDOM_FALLBACK = "random_fallback"


def _is_circulating(design: dict[str, Any] | None) -> bool:
    if not isinstance(design, dict):
        return False
    world = str(design.get("worldState") or "").strip().lower()
    return not world or world == "active"


def _filter_circulating_candidates(candidate_ids: list[str]) -> list[str]:
    """Keep access ids that still resolve to an Active (circulating) design."""
    out: list[str] = []
    seen: set[str] = set()
    for design_id in candidate_ids:
        iid = str(design_id or "").strip()
        if not iid or iid in seen:
            continue
        found = loader.find_design_by_internal_id(iid)
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
        found = loader.find_design_by_internal_id(design_id)
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
    """Pick one Arcori per seat in order. Returns {selections: [...]}."""
    if not isinstance(seats, list) or not seats:
        raise AppError(INVALID_QUERY, message="seats must be a non-empty list")

    table, table_fail = _load_weights_table()
    if table_fail and LOGGING_SWITCH:
        customlog(f"catalog_select: weights unavailable reason={table_fail}")

    selections: list[dict[str, Any]] = []
    seated_regions: list[str] = []

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
            design = loader.find_design_by_internal_id(chosen_id)
            region = _region_of(design)
            if region:
                seated_regions.append(region)

    return {"selections": selections}
