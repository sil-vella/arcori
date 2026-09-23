"""Avari profile read — identity from user row + persisted game profile."""

from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy.exc import IntegrityError

from core.state.session_scope import session_scope
from core.errors.app_error import AppError
from core.utils.dev_logger import customlog
from models.player_progress import PlayerKin
from modules.auth.auth_service import get_user_profile
from modules.avari import avari_repository as repo
from modules.avari.avari_errors import (
    INSUFFICIENT_GOLD,
    INVALID_KIN_COLOR,
    INVALID_KIN_REGION,
    INVALID_MATCH_FEE,
    INVALID_MATCH_FINALIZE,
    INVALID_QUERY,
    KIN_ALREADY_CLAIMED,
    KIN_CLAIM_FAILED,
    NOT_FOUND,
    REJECTED_KIN_NAME,
    SLAMMER_NO_CHARGES,
)
from modules.avari.rejected_words import is_rejected_kin_name
from modules.avari.gold_economy import (
    apply_fragment_delta,
    can_afford_fragments,
    match_fee_fragments,
)
from modules.avari.mastery_economy import (
    KIN_CREATOR_MASTERY_FLOOR,
    STARTER_INITIAL_MASTERY,
    compute_mastery_deltas,
    compute_mastery_value,
    mastery_value_label,
)
from modules.achievements.achievements_service import (
    apply_match_unlocks,
    apply_win_streak,
)
from modules.catalog.catalog_select import count_circulating_playable_arcori
from modules.avari.kin_genesis import (
    EXCLUDED_KIN_REGION,
    assert_design_key_parity,
    attach_lottie_face,
    build_kin_catalog_design,
    mint_internal_id,
    normalize_color,
    subtheme_for_type,
)
from modules.catalog.catalog_ids import art_basename
from modules.catalog.catalog_errors import NOT_FOUND as CATALOG_NOT_FOUND
from modules.catalog.catalog_service import get_design
from modules.catalog.kin_design_store import (
    lottie_public_url,
    write_design_file,
    write_lottie_file,
)
LOGGING_SWITCH = True

SOURCE_OWNED = "owned"
SOURCE_FALLBACK = "fallback"
SOURCE_EMPTY = "empty"


def list_design_access_ids(user_id: str) -> list[str]:
    """Circulating play/mastery access design ids for a user (match selection)."""
    uid = (user_id or "").strip()
    if not uid:
        return []
    with session_scope() as session:
        sync_player_access_pool(session, uid)
        rows = repo.list_design_access(session, uid)
        out: list[str] = []
        seen: set[str] = set()
        for row in rows:
            design_id = str(getattr(row, "design_id", "") or "").strip()
            if not design_id or design_id in seen:
                continue
            seen.add(design_id)
            out.append(design_id)
        return out


def sync_player_access_pool(session: Any, user_id: str) -> str | None:
    """
    Align access with mastery rules:
    - Own Kin: access kept; mastery floored at KIN_CREATOR_MASTERY_FLOOR.
    - Starter rows at 0 mastery: seed STARTER_INITIAL_MASTERY (keep pool).
    - Other designs at 0 mastery: revoke access.
    - Mastery > 0 without access: grant access (source=mastery).
    Returns own Kin design id when present.
    """
    uid = (user_id or "").strip()
    if not uid:
        return None
    kin = repo.find_player_kin(session, uid)
    own_kin_id = (
        str(kin.genesis_design_id or "").strip() if kin is not None else ""
    ) or None

    if own_kin_id and kin is not None:
        raw_design = getattr(kin, "catalog_design", None)
        gen = (
            generation_number_for_design(dict(raw_design))
            if isinstance(raw_design, dict)
            else generation_number_for_design_id(own_kin_id)
        )
        repo.ensure_design_access(
            session, user_id=uid, design_id=own_kin_id, source="kin"
        )
        repo.ensure_mastery_row(
            session,
            user_id=uid,
            design_id=own_kin_id,
            generation_number=gen,
            initial_points=KIN_CREATOR_MASTERY_FLOOR,
            floor=KIN_CREATOR_MASTERY_FLOOR,
        )

    mastery_by = repo.mastery_points_by_design(session, uid)
    access_rows = repo.list_design_access(session, uid)
    access_ids = {
        str(row.design_id or "").strip()
        for row in access_rows
        if str(row.design_id or "").strip()
    }

    for row in access_rows:
        did = str(row.design_id or "").strip()
        if not did:
            continue
        if own_kin_id and did == own_kin_id:
            continue
        pts = int(mastery_by.get(did, 0))
        source = str(row.source or "").strip().lower()
        if source == "starter" and pts < STARTER_INITIAL_MASTERY:
            gen = generation_number_for_design_id(did)
            row_m = repo.ensure_mastery_row(
                session,
                user_id=uid,
                design_id=did,
                generation_number=gen,
                initial_points=STARTER_INITIAL_MASTERY,
            )
            if int(row_m.points) < STARTER_INITIAL_MASTERY:
                row_m.points = STARTER_INITIAL_MASTERY
                session.flush()
            mastery_by[did] = STARTER_INITIAL_MASTERY
            pts = STARTER_INITIAL_MASTERY
        if pts <= 0:
            repo.revoke_design_access(session, user_id=uid, design_id=did)
            access_ids.discard(did)

    for did, pts in list(mastery_by.items()):
        if int(pts) <= 0:
            continue
        if did in access_ids:
            continue
        repo.ensure_design_access(
            session, user_id=uid, design_id=did, source="mastery"
        )
        access_ids.add(did)

    # Drop access to Closed catalog designs (preserved / lost generations).
    # Heals leftover access after GEN id cutover + preserve on a sibling id.
    from core.errors.app_error import AppError
    from models.legacy_preserve import PHASE_LOST_CLOSED, PHASE_PRESERVED
    from modules.catalog import catalog_repository as catalog_repo
    from modules.catalog.catalog_ids import (
        design_id_aliases,
        generation_number_from_id,
    )
    from modules.catalog.catalog_service import get_design
    from modules.legacy import legacy_repository as legacy_repo

    for did in list(access_ids):
        if own_kin_id and did == own_kin_id:
            continue
        gen = generation_number_from_id(did)
        life_closed = False
        for alias in design_id_aliases(did):
            life = legacy_repo.get_lifecycle(session, alias, gen)
            if life is not None and life.phase in (
                PHASE_PRESERVED,
                PHASE_LOST_CLOSED,
            ):
                life_closed = True
                break
        circulating = True
        if life_closed:
            catalog_repo.mark_closed(session, did)
            circulating = False
        else:
            try:
                design = get_design(did)
                circulating = _is_circulating(design)
            except AppError:
                circulating = True
            except Exception:
                circulating = True
        if not circulating:
            repo.revoke_design_access(session, user_id=uid, design_id=did)
            access_ids.discard(did)

    session.flush()
    return own_kin_id


def list_slammer_design_ids(user_id: str) -> list[str]:
    """Owned slammer design ids for a user (Game Controls / match verify)."""
    uid = (user_id or "").strip()
    if not uid:
        return []
    with session_scope() as session:
        rows = repo.list_slammers(session, uid)
        out: list[str] = []
        seen: set[str] = set()
        for row in rows:
            design_id = str(getattr(row, "design_id", "") or "").strip()
            if not design_id or design_id in seen:
                continue
            seen.add(design_id)
            out.append(design_id)
        return out


def _is_circulating(design: dict[str, Any] | None) -> bool:
    if not isinstance(design, dict):
        return False
    world = str(design.get("worldState") or "").strip().lower()
    return not world or world == "active"


def _gameplay_attributes(design: dict[str, Any]) -> dict[str, Any] | None:
    """Catalog slam stats + preferred slam conditions. Omitted when none."""
    raw = design.get("gameplayAttributes")
    if not isinstance(raw, dict):
        return None
    out: dict[str, Any] = {}
    for key in ("impact", "precision", "control", "recovery", "spread"):
        value = raw.get(key)
        if isinstance(value, bool):
            continue
        if isinstance(value, int):
            out[key] = max(1, min(10, value))
        elif isinstance(value, float):
            out[key] = max(1, min(10, int(value)))
        elif isinstance(value, str) and value.strip().isdigit():
            out[key] = max(1, min(10, int(value.strip())))

    hit_raw = raw.get("hitTarget")
    if isinstance(hit_raw, str):
        hit = hit_raw.strip().lower()
        if hit in ("center", "mid", "edge"):
            out["hitTarget"] = hit

    bracket = _power_bracket(raw.get("powerBracket"))
    if bracket is not None:
        out["powerBracket"] = bracket

    return out or None


def _clamp01(value: float) -> float:
    return max(0.0, min(1.0, value))


def _power_bracket(raw: Any) -> dict[str, float] | None:
    """Preferred resolve-power band {min,max} in 0..1 (0=none, 1=full)."""
    if isinstance(raw, bool) or raw is None:
        return None

    def _as_float(value: Any) -> float | None:
        if isinstance(value, bool):
            return None
        if isinstance(value, (int, float)):
            return float(value)
        if isinstance(value, str):
            try:
                return float(value.strip())
            except ValueError:
                return None
        return None

    lo: float | None = None
    hi: float | None = None

    if isinstance(raw, dict):
        lo = _as_float(raw.get("min"))
        hi = _as_float(raw.get("max"))
    elif isinstance(raw, (list, tuple)) and len(raw) >= 2:
        lo = _as_float(raw[0])
        hi = _as_float(raw[1])
    else:
        # Legacy single preferred power → narrow band around it.
        center = _as_float(raw)
        if center is not None:
            lo = center - 0.1
            hi = center + 0.1

    if lo is None or hi is None:
        return None
    lo_c = _clamp01(lo)
    hi_c = _clamp01(hi)
    if hi_c < lo_c:
        lo_c, hi_c = hi_c, lo_c
    return {"min": lo_c, "max": hi_c}


def catalog_card_for_design(design_id: str) -> dict[str, Any] | None:
    """Catalog face fields for profile / inventory (None if missing)."""
    iid = (design_id or "").strip()
    if not iid:
        return None
    try:
        design = get_design(iid)
    except AppError as err:
        if err.code != CATALOG_NOT_FOUND.code and LOGGING_SWITCH:
            customlog(f"avari: catalog card fail id={iid} code={err.code}")
        return None
    return catalog_card_from_design_doc(iid, design)


def _selection_weight_for_design(
    design_id: str,
    *,
    kin_design_id: str | None = None,
    kin_design_doc: dict[str, Any] | None = None,
) -> Any:
    """Resolve catalog selectionWeight for Mastery Value (None → formula default)."""
    iid = (design_id or "").strip()
    if (
        kin_design_id
        and iid == kin_design_id
        and isinstance(kin_design_doc, dict)
        and "selectionWeight" in kin_design_doc
    ):
        return kin_design_doc.get("selectionWeight")
    try:
        design = get_design(iid)
    except AppError:
        return None
    if isinstance(design, dict):
        return design.get("selectionWeight")
    return None


def compute_profile_mastery_value(
    mastery_by_design: dict[str, int],
    *,
    kin_design_id: str | None = None,
    kin_design_doc: dict[str, Any] | None = None,
) -> int:
    """Rounded Mastery Value: Σ points × (10 / selectionWeight)."""
    rows: list[tuple[int, Any]] = []
    for design_id, pts in mastery_by_design.items():
        did = str(design_id or "").strip()
        if not did:
            continue
        weight = _selection_weight_for_design(
            did,
            kin_design_id=kin_design_id,
            kin_design_doc=kin_design_doc,
        )
        rows.append((int(pts), weight))
    return int(round(compute_mastery_value(rows)))


def compute_profile_mastery_value_label(
    mastery_by_design: dict[str, int],
    *,
    kin_design_id: str | None = None,
    kin_design_doc: dict[str, Any] | None = None,
    circulating_count: int | None = None,
) -> tuple[int, str]:
    """Return (rounded MasteryValue, Fair…Priceless label).

    density = MasteryValue / max(1, N) where N is global circulating playable
    catalog count (static, not Kin).
    """
    value = compute_profile_mastery_value(
        mastery_by_design,
        kin_design_id=kin_design_id,
        kin_design_doc=kin_design_doc,
    )
    n = (
        int(circulating_count)
        if circulating_count is not None
        else count_circulating_playable_arcori()
    )
    return value, mastery_value_label(value, n)

def mint_reach_for_design(design: dict[str, Any] | None) -> int | None:
    """Catalog mint reach = legacy.preservationRequirement (Genesis 500 / Pioneers 100)."""
    if not isinstance(design, dict):
        return None
    legacy = design.get("legacy")
    if not isinstance(legacy, dict):
        return None
    raw = legacy.get("preservationRequirement")
    try:
        n = int(raw)
    except (TypeError, ValueError):
        return None
    return n if n > 0 else None


def mint_reach_or_series_default(design: dict[str, Any] | None) -> int:
    """Mint reach from design legacy, else current series preservationRequirement."""
    reach = mint_reach_for_design(design)
    if reach is not None:
        return reach
    from modules.catalog.current_series import current_series

    return int(current_series()["legacy"]["preservationRequirement"])


def catalog_card_from_design_doc(
    design_id: str,
    design: dict[str, Any],
    *,
    display_name_override: str | None = None,
) -> dict[str, Any]:
    """Build a profile/inventory card from an in-memory design doc (no nested DB)."""
    iid = (design_id or "").strip()
    override = (display_name_override or "").strip()
    name = override or str(design.get("design") or "").strip() or iid
    image_url = design.get("imageUrl")
    lottie_url = design.get("lottieUrl")
    theme = str(design.get("theme") or "").strip().lower()
    theme_code = str(design.get("themeCode") or "").strip().upper()
    is_kin = theme == "kin" or theme_code == "KIN" or iid.upper().startswith("KIN-")
    if is_kin:
        # Always resolve via store so GEN-in-serial ids hit pre-GEN files on disk.
        lottie_url = lottie_public_url(iid)
    elif not (isinstance(lottie_url, str) and lottie_url.strip()):
        lottie_url = None
    else:
        lottie_url = lottie_url.strip()
    face_media = str(design.get("faceMedia") or "").strip().lower() or None
    if face_media not in ("webp", "lottie"):
        if lottie_url:
            face_media = "lottie"
        elif isinstance(image_url, str) and image_url.strip():
            face_media = "webp"
        else:
            face_media = None
    color_raw = design.get("color")
    color = str(color_raw).strip() if color_raw else ""
    attrs = _gameplay_attributes(design)
    card: dict[str, Any] = {
        "designId": iid,
        "displayName": name,
        "imageUrl": image_url if isinstance(image_url, str) and image_url.strip() else None,
        "lottieUrl": lottie_url,
        "faceMedia": face_media,
        "color": color or None,
        "circulating": _is_circulating(design),
        "theme": str(design.get("theme") or "").strip() or None,
        "generationNumber": generation_number_for_design(design),
        "mintReach": mint_reach_or_series_default(design),
    }
    if attrs is not None:
        card["gameplayAttributes"] = attrs
    return card


def _access_entry_from_card(
    card: dict[str, Any],
    *,
    source: str | None,
    mastery_points: int,
    background: dict[str, Any] | None = None,
) -> dict[str, Any]:
    entry: dict[str, Any] = {
        "designId": card["designId"],
        "displayName": card["displayName"],
        "imageUrl": card.get("imageUrl"),
        "lottieUrl": card.get("lottieUrl"),
        "faceMedia": card.get("faceMedia"),
        "color": card.get("color"),
        "source": source,
        "masteryPoints": int(mastery_points),
        "mintReach": card.get("mintReach"),
    }
    if isinstance(background, dict) and background:
        entry["background"] = background
    return entry


def generation_number_for_design(design: dict[str, Any] | None) -> int:
    """Active generation number from a catalog design doc (default 1)."""
    if not isinstance(design, dict):
        return 1
    generation = design.get("generation")
    if isinstance(generation, dict):
        raw = generation.get("number")
        try:
            n = int(raw)
            return n if n >= 1 else 1
        except (TypeError, ValueError):
            return 1
    return 1


def generation_number_for_design_id(design_id: str) -> int:
    iid = (design_id or "").strip()
    if not iid:
        return 1
    from modules.catalog.catalog_ids import generation_number_from_id, parse_design_id

    parsed = parse_design_id(iid)
    if parsed is not None and parsed.has_gen:
        return parsed.generation_number
    try:
        return generation_number_for_design(get_design(iid))
    except AppError:
        return generation_number_from_id(iid, default=1)


def _slammer_usable(row: Any) -> bool:
    """Permanent always usable; charged slammers need charges_remaining > 0."""
    if bool(getattr(row, "permanent", False)):
        return True
    remaining = getattr(row, "charges_remaining", None)
    if remaining is None:
        return False
    try:
        return int(remaining) > 0
    except (TypeError, ValueError):
        return False


def _fallback_slammer_id(rows: list[Any]) -> str:
    for row in rows:
        if bool(getattr(row, "permanent", False)):
            design_id = str(getattr(row, "design_id", "") or "").strip()
            if design_id:
                return design_id
    for row in rows:
        if not _slammer_usable(row):
            continue
        design_id = str(getattr(row, "design_id", "") or "").strip()
        if design_id:
            return design_id
    return ""


def verify_slammers_for_seats(seats: list[dict[str, Any]]) -> dict[str, Any]:
    """Resolve one owned slammer per seat. Returns {assignments: [...]}."""
    if not isinstance(seats, list) or not seats:
        raise AppError(INVALID_QUERY, message="seats must be a non-empty list")

    assignments: list[dict[str, Any]] = []
    for raw in seats:
        if not isinstance(raw, dict):
            raise AppError(INVALID_QUERY, message="each seat must be an object")
        user_id = str(raw.get("userId") or "").strip()
        if not user_id:
            raise AppError(INVALID_QUERY, message="seat.userId required")
        requested = str(raw.get("slammerId") or "").strip()

        with session_scope() as session:
            rows = repo.list_slammers(session, user_id)

        usable_by_id: dict[str, Any] = {}
        owned: list[str] = []
        seen: set[str] = set()
        for row in rows:
            design_id = str(getattr(row, "design_id", "") or "").strip()
            if not design_id or design_id in seen:
                continue
            seen.add(design_id)
            owned.append(design_id)
            if _slammer_usable(row):
                usable_by_id[design_id] = row

        if requested and requested in usable_by_id:
            chosen = requested
            source = SOURCE_OWNED
            reason = "owned"
        else:
            chosen = _fallback_slammer_id(rows)
            if chosen:
                source = SOURCE_FALLBACK
                if requested and requested in seen and requested not in usable_by_id:
                    reason = "no_charges"
                elif requested:
                    reason = "not_owned"
                else:
                    reason = "missing_request"
            else:
                source = SOURCE_EMPTY
                reason = "empty_player_slammers"

        if LOGGING_SWITCH:
            customlog(
                f"avari: verify_slammer user={user_id} requested={requested or '-'} "
                f"chosen={chosen or '-'} source={source} reason={reason} "
                f"owned={len(owned)}"
            )
        assignments.append(
            {
                "userId": user_id,
                "slammerId": chosen,
                "source": source,
                "reason": reason,
            }
        )

    return {"assignments": assignments}


def spend_slammer_charge(
    *,
    user_id: str,
    design_id: str,
    match_id: str | None = None,
    intent_id: str | None = None,
) -> dict[str, Any]:
    """
    Deduct chargeCostPerUse for a non-permanent slammer slam.

    Permanent / missing ownership → no-op success.
    Zero charges → avari/slammer_no_charges.
    Optional intent_id reuses match_fee_ledger (kind=slammer_charge) for idempotency.
    """
    uid = (user_id or "").strip()
    did = (design_id or "").strip()
    if not uid or not did:
        raise AppError(INVALID_QUERY, message="userId and designId required")

    intent = (intent_id or "").strip()
    if len(intent) > 64:
        intent = intent[:64]

    from modules.market.market_skus import parse_slammer_economy

    try:
        with session_scope() as session:
            if intent:
                existing = repo.get_match_fee(
                    session, uid, intent, repo.FEE_KIND_SLAMMER_CHARGE
                )
                if existing is not None:
                    cached = (
                        existing.response_json
                        if isinstance(existing.response_json, dict)
                        else {}
                    )
                    return {
                        "spent": bool(cached.get("spent", True)),
                        "noop": bool(cached.get("noop", False)),
                        "designId": did,
                        "chargesRemaining": cached.get("chargesRemaining"),
                        "intentId": intent,
                    }

            row = None
            for candidate in repo.list_slammers(session, uid):
                if str(getattr(candidate, "design_id", "") or "").strip() == did:
                    row = candidate
                    break

            if row is None or bool(row.permanent):
                payload = {
                    "spent": False,
                    "noop": True,
                    "designId": did,
                    "chargesRemaining": None,
                    "intentId": intent or None,
                }
                if intent:
                    repo.insert_match_fee(
                        session,
                        user_id=uid,
                        intent_id=intent,
                        kind=repo.FEE_KIND_SLAMMER_CHARGE,
                        response=payload,
                    )
                    session.flush()
                return payload

            remaining = int(row.charges_remaining or 0)
            if remaining <= 0:
                raise AppError(SLAMMER_NO_CHARGES)

            cost = 1
            try:
                design = get_design(did)
                eco = parse_slammer_economy(design)
                cost = max(1, int(eco.get("chargeCostPerUse") or 1))
            except AppError:
                cost = 1

            if remaining < cost:
                raise AppError(SLAMMER_NO_CHARGES)

            row.charges_remaining = remaining - cost
            payload = {
                "spent": True,
                "noop": False,
                "designId": did,
                "chargesSpent": cost,
                "chargesRemaining": int(row.charges_remaining),
                "matchId": (match_id or "").strip() or None,
                "intentId": intent or None,
            }
            if intent:
                repo.insert_match_fee(
                    session,
                    user_id=uid,
                    intent_id=intent,
                    kind=repo.FEE_KIND_SLAMMER_CHARGE,
                    response=payload,
                )
            session.flush()
            if LOGGING_SWITCH:
                customlog(
                    f"avari: spend_slammer_charge user={uid} design={did} "
                    f"cost={cost} remaining={row.charges_remaining} "
                    f"intent={intent or '-'}"
                )
            return payload
    except IntegrityError:
        if not intent:
            raise
        with session_scope() as session:
            raced = repo.get_match_fee(
                session, uid, intent, repo.FEE_KIND_SLAMMER_CHARGE
            )
            if raced is not None and isinstance(raced.response_json, dict):
                cached = raced.response_json
                return {
                    "spent": bool(cached.get("spent", True)),
                    "noop": bool(cached.get("noop", False)),
                    "designId": did,
                    "chargesRemaining": cached.get("chargesRemaining"),
                    "intentId": intent,
                }
        raise


def get_avari_profile(user_id: str) -> dict[str, Any]:
    uid = (user_id or "").strip()
    if not uid:
        raise AppError(INVALID_QUERY, message="Unauthorized")

    profile = get_user_profile(uid)
    if profile is None:
        raise AppError(NOT_FOUND, message="Avari profile not found")

    display_name = str(profile.get("username") or "").strip() or "Avari"
    account_type = str(profile.get("account_type") or "Regular")

    with session_scope() as session:
        avari = repo.ensure_avari_profile(
            session,
            user_id=uuid.UUID(uid),
            display_name=display_name,
        )
        kin = repo.find_player_kin(session, uid)
        sync_player_access_pool(session, uid)
        access_rows = repo.list_design_access(session, uid)
        slammer_rows = repo.list_slammers(session, uid)
        trove_rows = repo.list_trove(session, uid)
        closed_gen_rows = repo.list_closed_generations(session, uid)

        if avari is not None:
            display_name = (avari.display_name or display_name).strip() or display_name
            titles = list(avari.titles or ["Avari"])
            if not titles:
                titles = ["Avari"]
            primary_title = avari.primary_title or titles[0]
            rank = {
                "xp": int(avari.rank_xp),
                "level": int(avari.rank_level),
                "label": avari.rank_label,
            }
            stats = {
                "matchesPlayed": int(avari.matches_played),
                "wins": int(avari.wins),
                "flips": int(avari.flips),
            }
            economy = {
                "goldFragments": int(avari.gold_fragments),
                "goldArcori": int(avari.gold_arcori),
            }
            onboarding = {
                "completed": bool(avari.onboarding_completed),
                "kinChosen": bool(avari.onboarding_kin_chosen),
                "genesisCreated": bool(avari.onboarding_genesis_created),
                "starterGranted": bool(avari.onboarding_starter_granted),
                "guidedPracticeDone": bool(avari.onboarding_guided_practice_done),
                "introsDone": bool(avari.onboarding_intros_done),
            }
            daily = {
                "loginStreak": int(avari.daily_login_streak),
                "lastLoginRewardAt": (
                    avari.daily_last_login_reward_at.isoformat()
                    if avari.daily_last_login_reward_at
                    else None
                ),
                "cacheClaimedAt": (
                    avari.daily_cache_claimed_at.isoformat()
                    if avari.daily_cache_claimed_at
                    else None
                ),
                "noMissStreak": int(avari.daily_no_miss_streak),
            }
            preferences = {
                "notifications": {"push": bool(avari.notifications_push)},
            }
        else:
            titles = ["Avari"]
            primary_title = "Avari"
            rank = {"xp": 0, "level": 1, "label": None}
            stats = {"matchesPlayed": 0, "wins": 0, "flips": 0}
            economy = {"goldFragments": 0, "goldArcori": 0}
            onboarding = {
                "completed": False,
                "kinChosen": False,
                "genesisCreated": False,
                "starterGranted": False,
                "guidedPracticeDone": False,
                "introsDone": False,
            }
            daily = {
                "loginStreak": 0,
                "lastLoginRewardAt": None,
                "cacheClaimedAt": None,
                "noMissStreak": 0,
            }
            preferences = {"notifications": {"push": True}}

        kin_payload = repo.serialize_kin(kin)
        access_design_ids = [
            str(row.design_id or "").strip()
            for row in access_rows
            if str(row.design_id or "").strip()
        ]
        kin_design_doc: dict[str, Any] | None = None
        kin_design_id = ""
        if kin is not None:
            kin_design_id = str(kin.genesis_design_id or "").strip()
            raw_kin_design = getattr(kin, "catalog_design", None)
            if isinstance(raw_kin_design, dict):
                kin_design_doc = dict(raw_kin_design)

        # Persist a per-player mastery row for every circulating access design.
        for design_id in access_design_ids:
            if kin_design_doc is not None and design_id == kin_design_id:
                card = catalog_card_from_design_doc(
                    design_id,
                    kin_design_doc,
                    display_name_override=str(getattr(kin, "chosen_name", "") or ""),
                )
            else:
                card = catalog_card_for_design(design_id)
            if card is None or not card.get("circulating"):
                continue
            gen = int(card.get("generationNumber") or 1)
            repo.ensure_mastery_row(
                session,
                user_id=uid,
                design_id=design_id,
                generation_number=gen,
            )
        # Kin Genesis design also gets a mastery row (may already be in access).
        if kin_design_id and kin_design_doc is not None:
            gen = generation_number_for_design(kin_design_doc)
            repo.ensure_mastery_row(
                session,
                user_id=uid,
                design_id=kin_design_id,
                generation_number=gen,
            )
        elif kin_design_id:
            repo.ensure_mastery_row(
                session,
                user_id=uid,
                design_id=kin_design_id,
                generation_number=generation_number_for_design_id(kin_design_id),
            )
        session.flush()
        mastery_by_design = repo.mastery_points_by_design(session, uid)
        designs_tracked = repo.count_mastery_designs(session, uid)
        mastery_rows = repo.list_mastery_top(session, uid, limit=5)
        mastery_top = [
            f"{row.design_id}:{row.points}" for row in mastery_rows
        ]
        mastery_value, mastery_label = compute_profile_mastery_value_label(
            mastery_by_design,
            kin_design_id=kin_design_id,
            kin_design_doc=kin_design_doc if isinstance(kin_design_doc, dict) else None,
        )
        if isinstance(kin_payload, dict) and kin is not None and kin_design_id:
            kin_payload["masteryPoints"] = int(
                mastery_by_design.get(kin_design_id, 0)
            )
            kin_payload["mintReach"] = mint_reach_or_series_default(kin_design_doc)
        access_payload: list[dict[str, Any]] = []
        seen_access: set[str] = set()
        kin_background: dict[str, Any] | None = None
        if kin is not None:
            custom = getattr(kin, "customization", None)
            if isinstance(custom, dict):
                raw_bg = custom.get("background")
                if isinstance(raw_bg, dict) and raw_bg:
                    kin_background = dict(raw_bg)
        for row in access_rows:
            design_id = str(row.design_id or "").strip()
            if not design_id or design_id in seen_access:
                continue
            seen_access.add(design_id)
            if kin_design_doc is not None and design_id == kin_design_id:
                card = catalog_card_from_design_doc(
                    design_id,
                    kin_design_doc,
                    display_name_override=str(getattr(kin, "chosen_name", "") or ""),
                )
            else:
                card = catalog_card_for_design(design_id)
            if card is None or not card.get("circulating"):
                continue
            access_payload.append(
                _access_entry_from_card(
                    card,
                    source=row.source,
                    mastery_points=int(mastery_by_design.get(design_id, 0)),
                    background=kin_background if design_id == kin_design_id else None,
                )
            )
        # Kin is always first in the Arcori section when claimed.
        if kin_design_id and kin is not None:
            if kin_design_doc is not None:
                kin_card = catalog_card_from_design_doc(
                    kin_design_id,
                    kin_design_doc,
                    display_name_override=str(getattr(kin, "chosen_name", "") or ""),
                )
            else:
                kin_card = catalog_card_for_design(kin_design_id)
            if kin_card is None:
                # Seeded / legacy Kin rows may lack catalog_design and static lookup.
                custom = getattr(kin, "customization", None)
                color = None
                if isinstance(custom, dict):
                    raw_color = custom.get("color")
                    if raw_color:
                        color = str(raw_color).strip() or None
                kin_card = {
                    "designId": kin_design_id,
                    "displayName": str(getattr(kin, "chosen_name", "") or "").strip()
                    or kin_design_id,
                    "imageUrl": None,
                    "lottieUrl": lottie_public_url(kin_design_id),
                    "faceMedia": "lottie",
                    "color": color,
                    "circulating": True,
                    "mintReach": mint_reach_or_series_default(None),
                }
            if not kin_card.get("lottieUrl"):
                kin_card["lottieUrl"] = lottie_public_url(kin_design_id)
                kin_card["faceMedia"] = kin_card.get("faceMedia") or "lottie"
            if kin_card.get("circulating"):
                access_payload = [
                    a for a in access_payload if a.get("designId") != kin_design_id
                ]
                access_payload.insert(
                    0,
                    _access_entry_from_card(
                        kin_card,
                        source="kin",
                        mastery_points=int(
                            mastery_by_design.get(kin_design_id, 0)
                        ),
                        background=kin_background,
                    ),
                )
        slammer_payload: list[dict[str, Any]] = []
        seen_slammers: set[str] = set()
        for row in slammer_rows:
            design_id = str(row.design_id or "").strip()
            if not design_id or design_id in seen_slammers:
                continue
            seen_slammers.add(design_id)
            card = catalog_card_for_design(design_id) or {}
            entry: dict[str, Any] = {
                "designId": design_id,
                "displayName": card.get("displayName") or design_id,
                "imageUrl": card.get("imageUrl"),
                "color": card.get("color"),
                "permanent": bool(row.permanent),
                "chargesRemaining": row.charges_remaining,
                "source": row.source,
            }
            attrs = card.get("gameplayAttributes")
            if isinstance(attrs, dict) and attrs:
                entry["gameplayAttributes"] = attrs
            if not bool(row.permanent):
                try:
                    from modules.market.market_skus import parse_slammer_economy

                    design = get_design(design_id)
                    eco = parse_slammer_economy(design)
                    entry["maxCharges"] = eco.get("maxCharges")
                    entry["rechargePriceGoldArcori"] = eco.get(
                        "rechargePriceGoldArcori"
                    )
                    entry["rechargeCharges"] = eco.get("rechargeCharges")
                except AppError:
                    entry["maxCharges"] = 20
                    entry["rechargePriceGoldArcori"] = 4
                    entry["rechargeCharges"] = 100
            slammer_payload.append(entry)
        trove_payload = []
        for row in trove_rows:
            design_id = str(row.design_id or "").strip()
            if not design_id:
                continue
            card = catalog_card_for_design(design_id) or {}
            trove_payload.append(
                {
                    "designId": design_id,
                    "serial": design_id,
                    "displayName": card.get("displayName") or design_id,
                    "imageUrl": card.get("imageUrl"),
                    "lottieUrl": card.get("lottieUrl"),
                    "faceMedia": card.get("faceMedia"),
                    "color": card.get("color"),
                    "generationNumber": int(row.generation_number),
                    "mintedAt": row.minted_at.isoformat() if row.minted_at else None,
                    "legacyTitle": row.legacy_title,
                    "creatorAttributed": bool(row.creator_attributed),
                }
            )

        closed_generations_payload: list[dict[str, Any]] = []
        for row in closed_gen_rows:
            design_id = str(row.design_id or "").strip()
            if not design_id:
                continue
            card = catalog_card_for_design(design_id) or {}
            echo_id = str(row.echo_design_id or "").strip() or None
            echo_seeded = int(getattr(row, "echo_mastery_seeded", 0) or 0)
            echo_gen = getattr(row, "echo_generation_number", None)
            echo_gen_n = (
                int(echo_gen)
                if echo_gen is not None
                else int(row.generation_number) + 1
            )
            closed_generations_payload.append(
                {
                    "designId": design_id,
                    "serial": design_id,
                    "displayName": card.get("displayName") or design_id,
                    "imageUrl": card.get("imageUrl"),
                    "lottieUrl": card.get("lottieUrl"),
                    "faceMedia": card.get("faceMedia"),
                    "color": card.get("color"),
                    "generationNumber": int(row.generation_number),
                    "masteryPoints": int(row.mastery_points),
                    "echoMasterySeeded": echo_seeded,
                    "echoGenerationNumber": echo_gen_n,
                    "legacyState": str(row.legacy_state or "").strip().lower(),
                    "echoDesignId": echo_id,
                    "closedAt": (
                        row.closed_at.isoformat() if row.closed_at else None
                    ),
                }
            )

        from modules.legacy import legacy_repository as legacy_repo

        preservation_windows_payload: list[dict[str, Any]] = []
        player_design_ids = set(mastery_by_design.keys()) | seen_access
        if kin_design_id:
            player_design_ids.add(kin_design_id)
        for life in legacy_repo.list_open_preservation_windows(session):
            design_id = str(life.design_id or "").strip()
            if not design_id:
                continue
            offer_uid = (
                str(life.first_offer_user_id) if life.first_offer_user_id else ""
            )
            leader_uid = str(life.leader_user_id) if life.leader_user_id else ""
            if (
                design_id not in player_design_ids
                and uid not in (offer_uid, leader_uid)
            ):
                continue
            if kin_design_doc is not None and design_id == kin_design_id:
                card = catalog_card_from_design_doc(
                    design_id,
                    kin_design_doc,
                    display_name_override=str(getattr(kin, "chosen_name", "") or ""),
                )
            else:
                card = catalog_card_for_design(design_id)
            if card is None:
                card = {
                    "designId": design_id,
                    "displayName": design_id,
                    "imageUrl": None,
                    "lottieUrl": None,
                    "faceMedia": None,
                    "color": None,
                }
            entry = _access_entry_from_card(
                card,
                source="preservation_window",
                mastery_points=int(mastery_by_design.get(design_id, 0)),
                background=kin_background if design_id == kin_design_id else None,
            )
            # Profile caption uses masteryCap (closure) instead of mint reach.
            entry["masteryCap"] = int(life.closure_milestone)
            entry["phase"] = str(life.phase or "")
            entry["generationNumber"] = int(life.generation_number)
            preservation_windows_payload.append(entry)

        from modules.achievements import achievements_repository as ach_repo

        achievements_unlocked_ids = ach_repo.list_unlocked_ids(session, uid)
        if avari is not None:
            stats = {
                **stats,
                "winStreakCurrent": int(getattr(avari, "win_streak_current", 0) or 0),
                "winStreakBest": int(getattr(avari, "win_streak_best", 0) or 0),
            }

    return {
        "identity": {
            "userId": str(profile.get("user_id") or uid),
            "displayName": display_name,
            "email": profile.get("email"),
            "avatarUrl": profile.get("avatar_url"),
            "accountType": account_type,
            "title": primary_title,
        },
        "rank": rank,
        "titles": titles,
        "kin": kin_payload,
        "mastery": {
            "designsTracked": designs_tracked,
            "top": mastery_top,
            "masteryValue": mastery_value,
            "masteryValueLabel": mastery_label,
        },
        "stats": stats,
        "economy": economy,
        "onboarding": onboarding,
        "daily": daily,
        "preferences": preferences,
        "access": access_payload,
        "slammers": slammer_payload,
        "trove": trove_payload,
        "closedGenerations": closed_generations_payload,
        "preservationWindows": preservation_windows_payload,
        "achievementsUnlockedIds": achievements_unlocked_ids,
    }


def get_mastery_recent(user_id: str, *, limit: int = 5) -> dict[str, Any]:
    """Last N mastery deltas for the Home ticker."""
    uid = (user_id or "").strip()
    if not uid:
        raise AppError(INVALID_QUERY, message="Unauthorized")
    safe = max(1, min(int(limit), 20))
    with session_scope() as session:
        rows = repo.list_mastery_change_recent(session, uid, limit=safe)
        items = [
            {
                "designId": str(row.design_id),
                "generationNumber": int(row.generation_number),
                "delta": int(row.delta_points),
                "pointsAfter": int(row.total_points),
                "displayName": row.display_name or str(row.design_id),
                "imageUrl": row.image_url,
                "matchId": row.match_id,
                "createdAt": row.created_at.isoformat() if row.created_at else None,
            }
            for row in rows
        ]
    return {"items": items}


def _valid_region_codes() -> set[str]:
    from modules.catalog import catalog_loader as loader

    meta = loader.load_meta("regions")
    regions = meta.get("regions") if isinstance(meta, dict) else None
    out: set[str] = set()
    if not isinstance(regions, list):
        return out
    for row in regions:
        if not isinstance(row, dict):
            continue
        code = str(row.get("regionCode") or "").strip().upper()
        if code:
            out.add(code)
    return out


def _write_kin_media(
    internal_id: str,
    *,
    catalog_design: dict[str, Any],
    lottie: dict[str, Any] | None,
) -> None:
    """One design JSON + optional Lottie per Kin (atomic files; no shared category)."""
    write_design_file(internal_id, catalog_design)
    if isinstance(lottie, dict):
        write_lottie_file(internal_id, lottie)


def claim_kin(user_id: str, body: dict[str, Any] | None) -> dict[str, Any]:
    """Create player_kin + mirrored Kin-series catalog_design; write per-Kin files."""
    uid = (user_id or "").strip()
    if not uid:
        raise AppError(INVALID_QUERY, message="Unauthorized")
    if not isinstance(body, dict):
        raise AppError(INVALID_QUERY, message="JSON body required")

    kin_serial = str(body.get("kinSerial") or "").strip()
    type_serial = str(body.get("typeSerial") or "").strip()
    chosen_name = str(body.get("chosenName") or "").strip()
    region_code = str(body.get("regionCode") or "").strip().upper()
    color = normalize_color(str(body.get("color") or ""))
    applied = body.get("applied")
    lottie = body.get("lottie")
    background = body.get("background")

    if not kin_serial or not type_serial:
        raise AppError(INVALID_QUERY, message="kinSerial and typeSerial are required")
    if not chosen_name:
        raise AppError(INVALID_QUERY, message="chosenName is required")
    if len(chosen_name) > 64:
        raise AppError(INVALID_QUERY, message="chosenName too long")
    if is_rejected_kin_name(chosen_name):
        raise AppError(REJECTED_KIN_NAME)
    if not region_code or region_code == EXCLUDED_KIN_REGION:
        raise AppError(INVALID_KIN_REGION, message="Realm Beyond is not assignable")
    valid_regions = _valid_region_codes()
    if valid_regions and region_code not in valid_regions:
        raise AppError(INVALID_KIN_REGION, message=f"Unknown region: {region_code}")
    if color is None:
        raise AppError(INVALID_KIN_COLOR)
    if applied is not None and not isinstance(applied, list):
        raise AppError(INVALID_QUERY, message="applied must be a list")
    if lottie is not None and not isinstance(lottie, dict):
        raise AppError(INVALID_QUERY, message="lottie must be an object")
    if background is not None and not isinstance(background, dict):
        raise AppError(INVALID_QUERY, message="background must be an object")

    profile = get_user_profile(uid)
    if profile is None:
        raise AppError(NOT_FOUND, message="Avari profile not found")
    username = str(profile.get("username") or "player")

    subtheme = subtheme_for_type(type_serial)
    style = "Chibi"
    finish = "Standard"
    effect = "None"

    with session_scope() as session:
        existing = repo.find_player_kin(session, uid)
        if existing is not None:
            raise AppError(KIN_ALREADY_CLAIMED)

        avari = repo.ensure_avari_profile(
            session,
            user_id=uuid.UUID(uid),
            display_name=username,
        )
        seq = repo.count_player_kin(session) + 1
        internal_id = mint_internal_id(username=username, seq=seq)
        try:
            catalog_design = build_kin_catalog_design(
                internal_id=internal_id,
                chosen_name=chosen_name,
                region_code=region_code,
                color=color,
                subtheme=subtheme,
                player_id=uid,
                style=style,
                finish=finish,
                effect=effect,
            )
            assert_design_key_parity(catalog_design)
            # Face art is the claimed Lottie (webp optional for other Arcori).
            catalog_design = attach_lottie_face(catalog_design, internal_id)
            assert_design_key_parity(catalog_design)
        except ValueError as exc:
            if LOGGING_SWITCH:
                customlog(f"avari: kin design parity fail {exc}")
            raise AppError(KIN_CLAIM_FAILED, message=str(exc)) from exc

        media_stem = art_basename(internal_id) or internal_id
        customization: dict[str, Any] = {
            "kinSerial": kin_serial,
            "typeSerial": type_serial,
            "regionCode": region_code,
            "color": color,
            "applied": applied if isinstance(applied, list) else [],
            "lottieRelativePath": f"kin/players/{media_stem}.json",
            "designRelativePath": f"kin/designs/{media_stem}.json",
        }
        if isinstance(background, dict) and background:
            customization["background"] = {
                "id": str(background.get("id") or "").strip() or None,
                "colorHex": str(background.get("colorHex") or "").strip() or None,
                "colorHexB": str(background.get("colorHexB") or "").strip() or None,
                "imageUrl": str(background.get("imageUrl") or "").strip() or None,
                "theme": str(background.get("theme") or "").strip() or None,
                "style": str(background.get("style") or "").strip() or None,
                "fileName": str(background.get("fileName") or "").strip() or None,
                "angleDegrees": background.get("angleDegrees"),
                "saturation": background.get("saturation"),
                "lightDark": background.get("lightDark"),
                "textureId": str(background.get("textureId") or "").strip() or None,
                "textureIntensity": background.get("textureIntensity"),
            }

        try:
            _write_kin_media(
                internal_id,
                catalog_design=catalog_design,
                lottie=lottie if isinstance(lottie, dict) else None,
            )
        except OSError as exc:
            if LOGGING_SWITCH:
                customlog(f"avari: kin media write fail {exc}")
            raise AppError(KIN_CLAIM_FAILED, message="Could not store Kin files") from exc

        row = PlayerKin(
            user_id=uuid.UUID(uid),
            subtheme=subtheme,
            style=style,
            finish=finish,
            effect=effect,
            genesis_design_id=internal_id,
            chosen_name=chosen_name[:64],
            customization=customization,
            catalog_design=catalog_design,
        )
        session.add(row)
        # Claimed Kin is circulating match stock: creator access + mastery floor 100.
        repo.ensure_design_access(
            session,
            user_id=uid,
            design_id=internal_id,
            source="kin",
        )
        repo.ensure_mastery_row(
            session,
            user_id=uid,
            design_id=internal_id,
            generation_number=generation_number_for_design(catalog_design),
            initial_points=KIN_CREATOR_MASTERY_FLOOR,
            floor=KIN_CREATOR_MASTERY_FLOOR,
        )
        avari.onboarding_kin_chosen = True
        avari.onboarding_genesis_created = True
        session.flush()
        if LOGGING_SWITCH:
            customlog(
                f"avari: kin claimed user={uid} design={internal_id} "
                f"region={region_code} color={color} url={lottie_public_url(internal_id)} "
                f"access=granted mastery={KIN_CREATOR_MASTERY_FLOOR}"
            )
        return {"kin": repo.serialize_kin(row)}


def _fee_cached_payload(stored: dict[str, Any] | None) -> dict[str, Any]:
    """Replay cached fee pay/refund body (ok:true success; no second wallet move)."""
    base: dict[str, Any] = dict(stored) if isinstance(stored, dict) else {}
    if "reason" not in base:
        base["reason"] = "already_applied"
    return base


def pay_match_fee(user_id: str, body: dict[str, Any] | None) -> dict[str, Any]:
    """Deduct online match fee before matchmaking. Practice must not call this."""
    uid = (user_id or "").strip()
    if not uid:
        raise AppError(INVALID_QUERY, message="Unauthorized")
    if not isinstance(body, dict):
        raise AppError(INVALID_MATCH_FEE, message="JSON body required")

    intent_id = str(body.get("feeIntentId") or body.get("fee_intent_id") or "").strip()
    if not intent_id:
        raise AppError(INVALID_MATCH_FEE, message="feeIntentId is required")

    match_type = str(body.get("matchType") or "").strip()
    if not match_type:
        raise AppError(INVALID_MATCH_FEE, message="matchType is required")
    if match_type.lower() == "practice":
        raise AppError(INVALID_MATCH_FEE, message="Practice has no match fee")

    event_id = str(body.get("eventId") or body.get("event_id") or "").strip()
    fee = match_fee_fragments(match_type, event_id=event_id or None)

    try:
        with session_scope() as session:
            existing = repo.get_match_fee(
                session, uid, intent_id, repo.FEE_KIND_PAY
            )
            if existing is not None:
                if LOGGING_SWITCH:
                    customlog(
                        f"avari: match fee pay already_applied user={uid} "
                        f"intent={intent_id}"
                    )
                return _fee_cached_payload(
                    existing.response_json
                    if isinstance(existing.response_json, dict)
                    else None
                )

            profile = get_user_profile(uid)
            display_name = (
                str((profile or {}).get("username") or "").strip() or "Avari"
            )
            avari = repo.ensure_avari_profile(
                session,
                user_id=uuid.UUID(uid),
                display_name=display_name,
            )
            before_a = int(avari.gold_arcori)
            before_f = int(avari.gold_fragments)
            if not can_afford_fragments(before_a, before_f, fee):
                raise AppError(
                    INSUFFICIENT_GOLD,
                    message=(
                        f"Not enough Gold Fragments. Online matches cost "
                        f"{fee} Gold Fragments."
                    ),
                )
            after_a, after_f, arcori_delta, _ = apply_fragment_delta(
                before_a, before_f, -fee
            )
            avari.gold_arcori = after_a
            avari.gold_fragments = after_f
            payload = {
                "paid": True,
                "matchType": match_type,
                "feeIntentId": intent_id,
                "feeFragments": fee,
                "goldFragmentsDelta": -fee,
                "goldArcoriDelta": arcori_delta,
                "goldFragments": after_f,
                "goldArcori": after_a,
            }
            repo.insert_match_fee(
                session,
                user_id=uid,
                intent_id=intent_id,
                kind=repo.FEE_KIND_PAY,
                response=payload,
            )
            session.flush()
            if LOGGING_SWITCH:
                customlog(
                    f"avari: match fee paid user={uid} type={match_type} "
                    f"intent={intent_id} fee={fee} goldArcori={after_a} "
                    f"frags={after_f}"
                )
            return payload
    except IntegrityError:
        with session_scope() as session:
            raced = repo.get_match_fee(
                session, uid, intent_id, repo.FEE_KIND_PAY
            )
            if raced is not None:
                if LOGGING_SWITCH:
                    customlog(
                        f"avari: match fee pay race→already_applied user={uid} "
                        f"intent={intent_id}"
                    )
                return _fee_cached_payload(
                    raced.response_json
                    if isinstance(raced.response_json, dict)
                    else None
                )
        raise


def refund_match_fee(user_id: str, body: dict[str, Any] | None) -> dict[str, Any]:
    """Refund pre-match fee when queue cancels before a match starts."""
    uid = (user_id or "").strip()
    if not uid:
        raise AppError(INVALID_QUERY, message="Unauthorized")
    if not isinstance(body, dict):
        raise AppError(INVALID_MATCH_FEE, message="JSON body required")

    intent_id = str(body.get("feeIntentId") or body.get("fee_intent_id") or "").strip()
    if not intent_id:
        raise AppError(INVALID_MATCH_FEE, message="feeIntentId is required")

    match_type = str(body.get("matchType") or "").strip()
    fee_raw = body.get("feeFragments")
    if fee_raw is None:
        fee = match_fee_fragments(match_type or "quickStart")
    else:
        try:
            fee = max(0, int(fee_raw))
        except (TypeError, ValueError) as exc:
            raise AppError(
                INVALID_MATCH_FEE, message="feeFragments must be an int"
            ) from exc

    if fee <= 0:
        return {
            "refunded": False,
            "reason": "no_fee",
            "feeIntentId": intent_id,
            "feeFragments": 0,
            "goldFragmentsDelta": 0,
            "goldArcoriDelta": 0,
            "goldFragments": 0,
            "goldArcori": 0,
        }

    try:
        with session_scope() as session:
            existing = repo.get_match_fee(
                session, uid, intent_id, repo.FEE_KIND_REFUND
            )
            if existing is not None:
                if LOGGING_SWITCH:
                    customlog(
                        f"avari: match fee refund already_applied user={uid} "
                        f"intent={intent_id}"
                    )
                return _fee_cached_payload(
                    existing.response_json
                    if isinstance(existing.response_json, dict)
                    else None
                )

            profile = get_user_profile(uid)
            display_name = (
                str((profile or {}).get("username") or "").strip() or "Avari"
            )
            avari = repo.ensure_avari_profile(
                session,
                user_id=uuid.UUID(uid),
                display_name=display_name,
            )
            before_a = int(avari.gold_arcori)
            before_f = int(avari.gold_fragments)
            after_a, after_f, arcori_delta, _ = apply_fragment_delta(
                before_a, before_f, fee
            )
            avari.gold_arcori = after_a
            avari.gold_fragments = after_f
            payload = {
                "refunded": True,
                "matchType": match_type,
                "feeIntentId": intent_id,
                "feeFragments": fee,
                "goldFragmentsDelta": fee,
                "goldArcoriDelta": arcori_delta,
                "goldFragments": after_f,
                "goldArcori": after_a,
            }
            repo.insert_match_fee(
                session,
                user_id=uid,
                intent_id=intent_id,
                kind=repo.FEE_KIND_REFUND,
                response=payload,
            )
            session.flush()
            if LOGGING_SWITCH:
                customlog(
                    f"avari: match fee refunded user={uid} type={match_type or '-'} "
                    f"intent={intent_id} fee={fee} goldArcori={after_a} "
                    f"frags={after_f}"
                )
            return payload
    except IntegrityError:
        with session_scope() as session:
            raced = repo.get_match_fee(
                session, uid, intent_id, repo.FEE_KIND_REFUND
            )
            if raced is not None:
                if LOGGING_SWITCH:
                    customlog(
                        f"avari: match fee refund race→already_applied "
                        f"user={uid} intent={intent_id}"
                    )
                return _fee_cached_payload(
                    raced.response_json
                    if isinstance(raced.response_json, dict)
                    else None
                )
        raise


def _already_applied_payload(stored: dict[str, Any] | None, match_id: str) -> dict[str, Any]:
    """Replay cached finalize body with applied=false (no second notify)."""
    base: dict[str, Any] = dict(stored) if isinstance(stored, dict) else {}
    base["applied"] = False
    base["reason"] = "already_applied"
    if "matchId" not in base:
        base["matchId"] = match_id
    return base


def finalize_match(user_id: str, body: dict[str, Any] | None) -> dict[str, Any]:
    """Post-match economy: flip fragments + per-player mastery (fee already paid)."""
    uid = (user_id or "").strip()
    if not uid:
        raise AppError(INVALID_QUERY, message="Unauthorized")
    if not isinstance(body, dict):
        raise AppError(INVALID_MATCH_FINALIZE, message="JSON body required")

    match_id = str(body.get("matchId") or "").strip()
    event_id = str(body.get("eventId") or body.get("event_id") or "").strip()
    match_type_raw = body.get("matchType")
    if isinstance(match_type_raw, dict):
        match_type = str(match_type_raw.get("code") or "").strip()
        if not event_id:
            event_id = str(
                match_type_raw.get("eventId") or match_type_raw.get("event_id") or ""
            ).strip()
    else:
        match_type = str(match_type_raw or "").strip()
    practice = body.get("practice") is True
    design_ids = body.get("designIds")
    result = body.get("result")
    played_raw = body.get("playedDesignId")
    played_design_id = str(played_raw or "").strip() if played_raw is not None else ""
    flips_by_design_raw = body.get("flipsByDesign")

    if not match_id:
        raise AppError(INVALID_MATCH_FINALIZE, message="matchId is required")
    if design_ids is not None and not isinstance(design_ids, list):
        raise AppError(INVALID_MATCH_FINALIZE, message="designIds must be a list")
    if result is not None and not isinstance(result, dict):
        raise AppError(INVALID_MATCH_FINALIZE, message="result must be an object")
    if flips_by_design_raw is not None and not isinstance(flips_by_design_raw, dict):
        raise AppError(
            INVALID_MATCH_FINALIZE, message="flipsByDesign must be an object"
        )

    cleaned_ids = (
        [str(x).strip() for x in design_ids if str(x).strip()]
        if isinstance(design_ids, list)
        else []
    )
    flips_by_design: dict[str, int] = {}
    if isinstance(flips_by_design_raw, dict):
        for key, value in flips_by_design_raw.items():
            did = str(key or "").strip()
            if not did:
                continue
            try:
                flips_by_design[did] = max(0, int(value))
            except (TypeError, ValueError):
                raise AppError(
                    INVALID_MATCH_FINALIZE,
                    message="flipsByDesign values must be ints",
                ) from None

    empty_economy = {
        "applied": False,
        "matchId": match_id,
        "goldFragmentsDelta": 0,
        "goldArcoriDelta": 0,
        "goldFragments": 0,
        "goldArcori": 0,
        "feeFragments": 0,
        "flipsRewarded": 0,
        "masteryChanges": [],
        "achievementsUnlocked": [],
        "daily": None,
        "eventProgress": None,
        "mint": None,
    }

    if practice:
        if LOGGING_SWITCH:
            customlog(
                f"avari: match finalize skipped practice user={uid} "
                f"matchId={match_id} type={match_type or '-'}"
            )
        return {**empty_economy, "reason": "practice"}

    flips_raw = body.get("flips")
    if flips_raw is None and isinstance(result, dict):
        flips_raw = result.get("flips")
    try:
        flips = max(0, int(flips_raw or 0))
    except (TypeError, ValueError):
        raise AppError(INVALID_MATCH_FINALIZE, message="flips must be an int") from None

    if not played_design_id and cleaned_ids:
        # Fallback: first design id from client match table (prefer human seat client-side).
        played_design_id = cleaned_ids[0]

    # Fee is charged pre-match (`pay_match_fee`); finalize only awards flip fragments.
    fee = 0
    # Prefer actor flips-by-design sum when the client sent the map (SSOT for
    # seat score / mastery). Legacy clients may only send `flips`.
    if flips_by_design_raw is not None:
        flips = sum(flips_by_design.values())
    net_fragments = flips

    won = False
    if isinstance(result, dict):
        winners = result.get("winnerUserIds")
        if isinstance(winners, list):
            won = any(str(w).strip() == uid for w in winners)

    first_apply = False
    applied_payload: dict[str, Any] | None = None

    try:
        with session_scope() as session:
            existing = repo.get_match_finalize(session, uid, match_id)
            if existing is not None:
                if LOGGING_SWITCH:
                    customlog(
                        f"avari: match finalize already_applied user={uid} "
                        f"matchId={match_id}"
                    )
                return _already_applied_payload(
                    existing.response_json
                    if isinstance(existing.response_json, dict)
                    else None,
                    match_id,
                )

            # Own curve applies to played + any table design you already have
            # mastery on (points > 0). Load before applying deltas.
            mastery_before = repo.mastery_points_by_design(session, uid)
            owned_ids = {
                did for did, pts in mastery_before.items() if int(pts) > 0
            }
            planned_mastery = compute_mastery_deltas(
                played_design_id=played_design_id or None,
                seat_flips=flips,
                flips_by_design=flips_by_design,
                table_design_ids=cleaned_ids,
                owned_design_ids=owned_ids,
            )

            profile = get_user_profile(uid)
            display_name = (
                str((profile or {}).get("username") or "").strip() or "Avari"
            )
            avari = repo.ensure_avari_profile(
                session,
                user_id=uuid.UUID(uid),
                display_name=display_name,
            )
            before_a = int(avari.gold_arcori)
            before_f = int(avari.gold_fragments)
            after_a, after_f, arcori_delta, _frag_field_delta = apply_fragment_delta(
                before_a,
                before_f,
                net_fragments,
            )
            avari.gold_arcori = after_a
            avari.gold_fragments = after_f
            avari.matches_played = int(avari.matches_played) + 1
            avari.flips = int(avari.flips) + flips
            if won:
                avari.wins = int(avari.wins) + 1

            streak_cur, streak_best = apply_win_streak(
                current=int(getattr(avari, "win_streak_current", 0) or 0),
                best=int(getattr(avari, "win_streak_best", 0) or 0),
                won=won,
            )
            avari.win_streak_current = streak_cur
            avari.win_streak_best = streak_best

            # Keep collection mastery rows present for every circulating access design.
            access_rows = repo.list_design_access(session, uid)
            for row in access_rows:
                design_id = str(row.design_id or "").strip()
                if not design_id:
                    continue
                gen = generation_number_for_design_id(design_id)
                repo.ensure_mastery_row(
                    session,
                    user_id=uid,
                    design_id=design_id,
                    generation_number=gen,
                )

            kin = repo.find_player_kin(session, uid)
            own_kin_id = (
                str(kin.genesis_design_id or "").strip() if kin is not None else ""
            ) or None

            mastery_changes: list[dict[str, Any]] = []
            for planned in planned_mastery:
                design_id = str(planned["designId"])
                delta = int(planned["delta"])
                gen = generation_number_for_design_id(design_id)
                floor = (
                    KIN_CREATOR_MASTERY_FLOOR
                    if own_kin_id and design_id == own_kin_id
                    else 0
                )
                _row, before_pts, after_pts = repo.apply_mastery_delta(
                    session,
                    user_id=uid,
                    design_id=design_id,
                    delta=delta,
                    generation_number=gen,
                    floor=floor,
                )
                # +mastery on another player's design → join circulating pool.
                if planned["kind"] == "other" and after_pts > before_pts and after_pts > 0:
                    repo.ensure_design_access(
                        session,
                        user_id=uid,
                        design_id=design_id,
                        source="mastery",
                    )
                # 0 mastery leaves the pool (own Kin floored above, never 0).
                if after_pts <= 0 and design_id != own_kin_id:
                    repo.revoke_design_access(
                        session, user_id=uid, design_id=design_id
                    )
                card = catalog_card_for_design(design_id) or {}
                change: dict[str, Any] = {
                    "designId": design_id,
                    "delta": after_pts - before_pts,
                    "pointsBefore": before_pts,
                    "pointsAfter": after_pts,
                    "flips": int(planned["flips"]),
                    "kind": planned["kind"],
                    "generationNumber": gen,
                    "mintReach": card.get("mintReach"),
                    "displayName": card.get("displayName") or design_id,
                    "imageUrl": card.get("imageUrl"),
                    "lottieUrl": card.get("lottieUrl"),
                    "faceMedia": card.get("faceMedia"),
                    "color": card.get("color"),
                }
                mastery_changes.append(change)
                if int(change.get("delta") or 0) != 0:
                    repo.append_mastery_change_log(
                        session,
                        user_id=uid,
                        design_id=design_id,
                        generation_number=gen,
                        delta_points=int(change["delta"]),
                        total_points=after_pts,
                        display_name=str(change.get("displayName") or "") or None,
                        image_url=str(change.get("imageUrl") or "") or None,
                        match_id=match_id,
                    )

            sync_player_access_pool(session, uid)
            session.flush()

            mastery_after: dict[str, int] = {}
            for mrow in repo.list_mastery_rows(session, uid):
                did = str(mrow.design_id or "").strip()
                if not did:
                    continue
                try:
                    pts = int(mrow.points or 0)
                except (TypeError, ValueError):
                    pts = 0
                prev = mastery_after.get(did, 0)
                if pts > prev:
                    mastery_after[did] = pts

            legacy_offers: list[dict[str, Any]] = []
            legacy_proximity: list[dict[str, Any]] = []
            legacy_event: dict[str, Any] | None = None
            mint_payload: dict[str, Any] | None = None
            from modules.legacy.legacy_service import on_mastery_progress

            for change in mastery_changes:
                did = str(change.get("designId") or "").strip()
                if not did:
                    continue
                try:
                    pts_after = int(change.get("pointsAfter") or 0)
                    pts_before = int(change.get("pointsBefore") or 0)
                    gen_n = int(
                        change.get("generationNumber")
                        or generation_number_for_design_id(did)
                    )
                except (TypeError, ValueError):
                    continue
                ev = on_mastery_progress(
                    session,
                    user_id=uid,
                    design_id=did,
                    generation_number=gen_n,
                    points_after=pts_after,
                    points_before=pts_before,
                )
                if not isinstance(ev, dict):
                    continue
                if isinstance(ev.get("legacyOffer"), dict):
                    offer = ev["legacyOffer"]
                    legacy_offers.append(offer)
                    if LOGGING_SWITCH:
                        customlog(
                            f"finalize_match: legacyOffer design={did} "
                            f"phase={offer.get('phase')} "
                            f"ptsAfter={pts_after} "
                            f"offerN={len(legacy_offers)}"
                        )
                prox = ev.get("legacyProximity")
                if isinstance(prox, list):
                    for row in prox:
                        if isinstance(row, dict):
                            legacy_proximity.append(row)
                    if LOGGING_SWITCH and prox:
                        customlog(
                            f"finalize_match: legacyProximity design={did} "
                            f"n={len(prox)} ptsBefore={pts_before} "
                            f"ptsAfter={pts_after}"
                        )
                if isinstance(ev.get("legacyEvent"), dict):
                    legacy_event = ev["legacyEvent"]
                    if isinstance(legacy_event.get("mint"), dict):
                        mint_payload = legacy_event.get("mint")
                    if LOGGING_SWITCH:
                        customlog(
                            f"finalize_match: legacyEvent design={did} "
                            f"reason={legacy_event.get('reason')}"
                        )

            event_progress: dict[str, Any] = {}
            is_special_event = match_type in ("specialEvent", "special_event")
            if is_special_event and event_id:
                from modules.special_events import special_events_repository as se_repo

                flipped_ids = [
                    did for did, count in flips_by_design.items() if int(count) > 0
                ]
                if (
                    played_design_id
                    and flips > 0
                    and played_design_id not in flipped_ids
                ):
                    flipped_ids.append(played_design_id)
                from modules.special_events.special_events_loader import event_by_id
                from modules.special_events.special_events_service import (
                    should_credit_match,
                )

                ev = event_by_id(event_id)
                do_credit = bool(
                    ev is not None and should_credit_match(ev, won=won, flips=flips)
                )
                snap = se_repo.apply_match_progress(
                    session,
                    user_id=uid,
                    event_id=event_id,
                    flips=flips,
                    flipped_design_ids=flipped_ids,
                    won=won,
                    match_id=match_id,
                    credit=do_credit,
                )
                event_progress[event_id] = snap

            achievements_unlocked = apply_match_unlocks(
                session,
                user_id=uid,
                wins=int(avari.wins),
                matches_played=int(avari.matches_played),
                flips=int(avari.flips),
                win_streak_current=int(avari.win_streak_current),
                is_winner=won,
                mastery_after=mastery_after,
                match_flags=set(),
                event_id=event_id or None,
                event_progress=event_progress,
            )
            session.flush()

            from modules.daily_goals.daily_goals_service import apply_match_event

            daily_payload = apply_match_event(
                session,
                user_id=uid,
                avari=avari,
                flips=flips,
                won=won,
            )
            session.flush()

            if LOGGING_SWITCH:
                customlog(
                    f"avari: match finalize applied user={uid} matchId={match_id} "
                    f"type={match_type or '-'} fee={fee} flips={flips} "
                    f"netFrags={net_fragments} goldArcori={after_a} frags={after_f} "
                    f"played={played_design_id or '-'} mastery={len(mastery_changes)} "
                    f"achievements={len(achievements_unlocked)} "
                    f"dailyChanged={daily_payload.get('changedGoalIds')} "
                    f"designs={len(cleaned_ids)}"
                )

            applied_payload = {
                "applied": True,
                "reason": "economy",
                "matchId": match_id,
                "goldFragmentsDelta": net_fragments,
                "goldArcoriDelta": arcori_delta,
                "goldFragments": after_f,
                "goldArcori": after_a,
                "feeFragments": fee,
                "flipsRewarded": flips,
                "masteryChanges": mastery_changes,
                "achievementsUnlocked": achievements_unlocked,
                "daily": daily_payload,
                "eventProgress": event_progress.get(event_id) if event_id else None,
                "mint": mint_payload,
                # All first-offer / leader-eligible events this match.
                "legacyOffers": legacy_offers,
                # First offer only — kept for older clients.
                "legacyOffer": legacy_offers[0] if legacy_offers else None,
                "legacyProximity": legacy_proximity,
                "legacyEvent": legacy_event,
            }
            repo.insert_match_finalize(
                session,
                user_id=uid,
                match_id=match_id,
                response=applied_payload,
            )
            first_apply = True
    except IntegrityError:
        # Concurrent double-POST: other txn won the unique (user, match) insert.
        with session_scope() as session:
            raced = repo.get_match_finalize(session, uid, match_id)
            if raced is not None:
                if LOGGING_SWITCH:
                    customlog(
                        f"avari: match finalize race→already_applied user={uid} "
                        f"matchId={match_id}"
                    )
                return _already_applied_payload(
                    raced.response_json
                    if isinstance(raced.response_json, dict)
                    else None,
                    match_id,
                )
        raise

    if applied_payload is None:
        raise AppError(INVALID_MATCH_FINALIZE, message="finalize produced no payload")

    # After DB commit: durable instant notes only on first apply (not replay).
    if first_apply:
        from modules.achievements.achievements_notifications import (
            notify_achievement_unlocks,
        )
        from modules.daily_goals.daily_goals_notifications import (
            notify_daily_completions,
        )
        from modules.legacy.legacy_notifications import (
            notify_legacy_leader_proximity,
            notify_legacy_offers,
        )

        unlocks = applied_payload.get("achievementsUnlocked") or []
        if isinstance(unlocks, list) and unlocks:
            notify_achievement_unlocks(
                user_id=uid,
                match_id=match_id,
                unlocked_rows=[r for r in unlocks if isinstance(r, dict)],
            )
        daily = applied_payload.get("daily")
        if isinstance(daily, dict):
            completed = daily.get("goalsCompleted") or []
            if isinstance(completed, list) and completed:
                notify_daily_completions(
                    user_id=uid,
                    day_key=str(daily.get("dayKey") or ""),
                    completed_rows=[r for r in completed if isinstance(r, dict)],
                )
        offers = applied_payload.get("legacyOffers") or []
        if isinstance(offers, list) and offers:
            notify_legacy_offers(
                user_id=uid,
                match_id=match_id,
                offers=[r for r in offers if isinstance(r, dict)],
            )
        proximity = applied_payload.get("legacyProximity") or []
        if isinstance(proximity, list) and proximity:
            notify_legacy_leader_proximity(
                events=[r for r in proximity if isinstance(r, dict)],
            )
        legacy_event = applied_payload.get("legacyEvent")
        if isinstance(legacy_event, dict) and legacy_event.get("applied"):
            from modules.notifications.world_news_notifications import (
                emit_world_news_for_closure_results,
            )

            emit_world_news_for_closure_results([legacy_event])

    return applied_payload
