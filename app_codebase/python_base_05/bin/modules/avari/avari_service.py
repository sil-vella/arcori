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
    INVALID_QUERY,
    KIN_ALREADY_CLAIMED,
    KIN_CLAIM_FAILED,
    NOT_FOUND,
)
from modules.avari.kin_genesis import (
    EXCLUDED_KIN_REGION,
    assert_design_key_parity,
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
    name = str(design.get("design") or "").strip() or iid
    image_url = design.get("imageUrl")
    color_raw = design.get("color")
    color = str(color_raw).strip() if color_raw else ""
    attrs = _gameplay_attributes(design)
    card: dict[str, Any] = {
        "designId": iid,
        "displayName": name,
        "imageUrl": image_url if isinstance(image_url, str) and image_url.strip() else None,
        "color": color or None,
        "circulating": _is_circulating(design),
        "theme": str(design.get("theme") or "").strip() or None,
    }
    if attrs is not None:
        card["gameplayAttributes"] = attrs
    return card


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
        avari.onboarding_kin_chosen = True
        avari.onboarding_genesis_created = True
        session.flush()
        if LOGGING_SWITCH:
            customlog(
                f"avari: kin claimed user={uid} design={internal_id} "
                f"region={region_code} color={color} url={lottie_public_url(internal_id)}"
            )
        return {"kin": repo.serialize_kin(row)}
