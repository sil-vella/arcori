"""Avari profile read — identity from user row + persisted game profile."""

from __future__ import annotations

import uuid
from typing import Any

from core.state.session_scope import session_scope
from core.errors.app_error import AppError
from core.utils.dev_logger import customlog
from models.player_progress import PlayerKin
from modules.auth.auth_service import get_user_profile
from modules.avari import avari_repository as repo
from modules.avari.avari_errors import (
    INVALID_KIN_COLOR,
    INVALID_KIN_REGION,
    INVALID_MATCH_FINALIZE,
    INVALID_QUERY,
    KIN_ALREADY_CLAIMED,
    KIN_CLAIM_FAILED,
    NOT_FOUND,
)
from modules.avari.gold_economy import (
    apply_fragment_delta,
    match_fee_fragments,
)
from modules.avari.mastery_economy import (
    KIN_CREATOR_MASTERY_FLOOR,
    STARTER_INITIAL_MASTERY,
    compute_mastery_deltas,
)
from modules.avari.kin_genesis import (
    EXCLUDED_KIN_REGION,
    assert_design_key_parity,
    attach_lottie_face,
    build_kin_catalog_design,
    mint_internal_id,
    normalize_color,
    subtheme_for_type,
)
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


def _gameplay_attributes(design: dict[str, Any]) -> dict[str, int] | None:
    """Catalog slam stats 1–10. Omitted when the design has none."""
    raw = design.get("gameplayAttributes")
    if not isinstance(raw, dict):
        return None
    out: dict[str, int] = {}
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
    return out or None


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
    if not (isinstance(lottie_url, str) and lottie_url.strip()):
        # Kin faces are Lottie; derive public URL when stamped face is missing.
        theme = str(design.get("theme") or "").strip().lower()
        theme_code = str(design.get("themeCode") or "").strip().upper()
        if theme == "kin" or theme_code == "KIN" or iid.upper().startswith("KIN-"):
            lottie_url = lottie_public_url(iid)
        else:
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
    try:
        return generation_number_for_design(get_design(iid))
    except AppError:
        return 1


def _fallback_slammer_id(rows: list[Any]) -> str:
    for row in rows:
        if bool(getattr(row, "permanent", False)):
            design_id = str(getattr(row, "design_id", "") or "").strip()
            if design_id:
                return design_id
    for row in rows:
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

        owned: list[str] = []
        seen: set[str] = set()
        for row in rows:
            design_id = str(getattr(row, "design_id", "") or "").strip()
            if not design_id or design_id in seen:
                continue
            seen.add(design_id)
            owned.append(design_id)

        if requested and requested in seen:
            chosen = requested
            source = SOURCE_OWNED
            reason = "owned"
        else:
            chosen = _fallback_slammer_id(rows)
            if chosen:
                source = SOURCE_FALLBACK
                reason = "not_owned" if requested else "missing_request"
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
            slammer_payload.append(entry)
        trove_payload = [
            {
                "designId": row.design_id,
                "generationNumber": int(row.generation_number),
                "mintedAt": row.minted_at.isoformat() if row.minted_at else None,
                "legacyTitle": row.legacy_title,
                "creatorAttributed": bool(row.creator_attributed),
            }
            for row in trove_rows
        ]

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
        },
        "stats": stats,
        "economy": economy,
        "onboarding": onboarding,
        "daily": daily,
        "preferences": preferences,
        "access": access_payload,
        "slammers": slammer_payload,
        "trove": trove_payload,
    }


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
    """Create player_kin + mirrored Genesis catalog_design; write per-Kin files."""
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

        customization: dict[str, Any] = {
            "kinSerial": kin_serial,
            "typeSerial": type_serial,
            "regionCode": region_code,
            "color": color,
            "applied": applied if isinstance(applied, list) else [],
            "lottieRelativePath": f"kin/players/{internal_id}.json",
            "designRelativePath": f"kin/designs/{internal_id}.json",
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


def finalize_match(user_id: str, body: dict[str, Any] | None) -> dict[str, Any]:
    """Post-match economy: fee + flip fragments + per-player mastery."""
    uid = (user_id or "").strip()
    if not uid:
        raise AppError(INVALID_QUERY, message="Unauthorized")
    if not isinstance(body, dict):
        raise AppError(INVALID_MATCH_FINALIZE, message="JSON body required")

    match_id = str(body.get("matchId") or "").strip()
    match_type = str(body.get("matchType") or "").strip()
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
        "rankXpDelta": 0,
        "masteryChanges": [],
        "daily": None,
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

    fee = match_fee_fragments(match_type)
    net_fragments = flips - fee
    planned_mastery = compute_mastery_deltas(
        played_design_id=played_design_id or None,
        seat_flips=flips,
        flips_by_design=flips_by_design,
    )

    won = False
    if isinstance(result, dict):
        winners = result.get("winnerUserIds")
        if isinstance(winners, list):
            won = any(str(w).strip() == uid for w in winners)

    with session_scope() as session:
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

        sync_player_access_pool(session, uid)
        session.flush()

        if LOGGING_SWITCH:
            customlog(
                f"avari: match finalize applied user={uid} matchId={match_id} "
                f"type={match_type or '-'} fee={fee} flips={flips} "
                f"netFrags={net_fragments} goldArcori={after_a} frags={after_f} "
                f"played={played_design_id or '-'} mastery={len(mastery_changes)} "
                f"designs={len(cleaned_ids)}"
            )

        return {
            "applied": True,
            "reason": "economy",
            "matchId": match_id,
            "goldFragmentsDelta": net_fragments,
            "goldArcoriDelta": arcori_delta,
            "goldFragments": after_f,
            "goldArcori": after_a,
            "feeFragments": fee,
            "flipsRewarded": flips,
            "rankXpDelta": 0,
            "masteryChanges": mastery_changes,
            "daily": None,
            "mint": None,
        }
