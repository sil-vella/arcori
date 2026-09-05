"""Avari profile read — identity from user row + persisted game profile."""

from __future__ import annotations

import uuid
from typing import Any

from core.state.session_scope import session_scope
from core.errors.app_error import AppError
from core.utils.dev_logger import customlog
from modules.auth.auth_service import get_user_profile
from modules.avari import avari_repository as repo
from modules.avari.avari_errors import INVALID_QUERY, NOT_FOUND
from modules.catalog.catalog_errors import NOT_FOUND as CATALOG_NOT_FOUND
from modules.catalog.catalog_service import get_design

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
    name = str(design.get("design") or "").strip() or iid
    image_url = design.get("imageUrl")
    color_raw = design.get("color")
    color = str(color_raw).strip() if color_raw else ""
    return {
        "designId": iid,
        "displayName": name,
        "imageUrl": image_url if isinstance(image_url, str) and image_url.strip() else None,
        "color": color or None,
        "circulating": _is_circulating(design),
        "theme": str(design.get("theme") or "").strip() or None,
    }


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
        mastery_rows = repo.list_mastery_top(session, uid, limit=5)
        designs_tracked = repo.count_mastery_designs(session, uid)
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
                "goldCaps": int(avari.gold_caps),
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
            economy = {"goldFragments": 0, "goldCaps": 0}
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

        mastery_top = [
            f"{row.design_id}:{row.points}" for row in mastery_rows
        ]
        kin_payload = repo.serialize_kin(kin)
        access_payload: list[dict[str, Any]] = []
        seen_access: set[str] = set()
        for row in access_rows:
            design_id = str(row.design_id or "").strip()
            if not design_id or design_id in seen_access:
                continue
            seen_access.add(design_id)
            card = catalog_card_for_design(design_id)
            if card is None or not card.get("circulating"):
                continue
            access_payload.append(
                {
                    "designId": design_id,
                    "displayName": card["displayName"],
                    "imageUrl": card.get("imageUrl"),
                    "color": card.get("color"),
                    "source": row.source,
                }
            )
        slammer_payload: list[dict[str, Any]] = []
        seen_slammers: set[str] = set()
        for row in slammer_rows:
            design_id = str(row.design_id or "").strip()
            if not design_id or design_id in seen_slammers:
                continue
            seen_slammers.add(design_id)
            card = catalog_card_for_design(design_id) or {}
            slammer_payload.append(
                {
                    "designId": design_id,
                    "displayName": card.get("displayName") or design_id,
                    "imageUrl": card.get("imageUrl"),
                    "color": card.get("color"),
                    "permanent": bool(row.permanent),
                    "chargesRemaining": row.charges_remaining,
                    "source": row.source,
                }
            )
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
