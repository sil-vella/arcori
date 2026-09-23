"""Market service — buy / recharge slammers for Gold Arcori."""

from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy.orm import Session

from core.errors.app_error import AppError
from core.utils.dev_logger import customlog
from modules.auth.auth_service import get_user_profile
from modules.avari import avari_repository as avari_repo
from modules.avari.gold_economy import normalize_wallet
from modules.catalog.catalog_errors import NOT_FOUND as CATALOG_NOT_FOUND
from modules.catalog.catalog_service import get_design
from modules.market.market_errors import (
    ALREADY_OWNED,
    INSUFFICIENT_GOLD,
    INVALID_QUERY,
    NOT_FOR_SALE,
    NOT_OWNED,
    PERMANENT_NO_RECHARGE,
)
from modules.market.market_skus import (
    MARKET_SLAMMER_IDS,
    is_market_slammer,
    parse_slammer_economy,
)

LOGGING_SWITCH = True


def _ensure_avari(session: Session, user_id: str):
    profile = get_user_profile(user_id)
    display_name = str((profile or {}).get("username") or "").strip() or "Avari"
    return avari_repo.ensure_avari_profile(
        session,
        user_id=uuid.UUID(user_id),
        display_name=display_name,
    )


def _design_or_raise(design_id: str) -> dict[str, Any]:
    try:
        return get_design(design_id)
    except AppError as err:
        if err.code == CATALOG_NOT_FOUND.code:
            raise AppError(NOT_FOR_SALE) from err
        raise


def _owned_row(session: Session, user_id: str, design_id: str):
    rows = avari_repo.list_slammers(session, user_id)
    for row in rows:
        if str(getattr(row, "design_id", "") or "").strip() == design_id:
            return row
    return None


def _sku_payload(
    design_id: str,
    design: dict[str, Any],
    *,
    owned: bool,
    charges_remaining: int | None,
    permanent: bool,
    gold_arcori: int,
) -> dict[str, Any]:
    eco = parse_slammer_economy(design)
    display = str(design.get("design") or design_id).strip() or design_id
    return {
        "designId": design_id,
        "displayName": display,
        "imageUrl": design.get("imageUrl"),
        "color": design.get("color"),
        "hitTarget": (design.get("gameplayAttributes") or {}).get("hitTarget")
        if isinstance(design.get("gameplayAttributes"), dict)
        else None,
        "powerBracket": (design.get("gameplayAttributes") or {}).get(
            "powerBracket"
        )
        if isinstance(design.get("gameplayAttributes"), dict)
        else None,
        "shopPriceGoldArcori": eco["shopPriceGoldArcori"],
        "rechargePriceGoldArcori": eco["rechargePriceGoldArcori"],
        "rechargeCharges": eco["rechargeCharges"],
        "maxCharges": eco["maxCharges"],
        "owned": owned,
        "permanent": permanent,
        "chargesRemaining": charges_remaining,
        "goldArcori": gold_arcori,
        "canAffordPurchase": (not owned)
        and gold_arcori >= int(eco["shopPriceGoldArcori"]),
        "canAffordRecharge": owned
        and (not permanent)
        and gold_arcori >= int(eco["rechargePriceGoldArcori"]),
    }


def list_market_slammers(session: Session, *, user_id: str) -> dict[str, Any]:
    avari = _ensure_avari(session, user_id)
    gold_a, gold_f = normalize_wallet(
        int(avari.gold_arcori), int(avari.gold_fragments)
    )
    if gold_a != int(avari.gold_arcori) or gold_f != int(avari.gold_fragments):
        avari.gold_arcori = gold_a
        avari.gold_fragments = gold_f
        session.flush()

    owned_by_id = {
        str(r.design_id).strip(): r for r in avari_repo.list_slammers(session, user_id)
    }
    items: list[dict[str, Any]] = []
    for design_id in MARKET_SLAMMER_IDS:
        design = _design_or_raise(design_id)
        row = owned_by_id.get(design_id)
        owned = row is not None
        permanent = bool(getattr(row, "permanent", False)) if owned else False
        charges = (
            None
            if permanent
            else (int(row.charges_remaining) if owned and row.charges_remaining is not None else 0)
            if owned
            else None
        )
        items.append(
            _sku_payload(
                design_id,
                design,
                owned=owned,
                charges_remaining=charges,
                permanent=permanent,
                gold_arcori=gold_a,
            )
        )
    return {"slammers": items, "goldArcori": gold_a, "goldFragments": gold_f}


def purchase_slammer(
    session: Session, *, user_id: str, design_id: str
) -> dict[str, Any]:
    did = (design_id or "").strip()
    if not did:
        raise AppError(INVALID_QUERY, message="designId required")
    if not is_market_slammer(did):
        raise AppError(NOT_FOR_SALE)

    design = _design_or_raise(did)
    eco = parse_slammer_economy(design)
    if eco["permanent"]:
        raise AppError(NOT_FOR_SALE, message="Permanent slammers are not sold here")

    existing = _owned_row(session, user_id, did)
    if existing is not None:
        raise AppError(ALREADY_OWNED)

    avari = _ensure_avari(session, user_id)
    gold_a, gold_f = normalize_wallet(
        int(avari.gold_arcori), int(avari.gold_fragments)
    )
    cost = int(eco["shopPriceGoldArcori"])
    if gold_a < cost:
        raise AppError(
            INSUFFICIENT_GOLD,
            message=f"Need {cost} Gold Arcori to buy this slammer",
        )
    avari.gold_arcori = gold_a - cost
    avari.gold_fragments = gold_f

    charges = int(eco["maxCharges"] or eco["rechargeCharges"] or 20)
    avari_repo.ensure_slammer(
        session,
        user_id=user_id,
        design_id=did,
        permanent=False,
        charges_remaining=charges,
        source="market",
    )
    session.flush()
    if LOGGING_SWITCH:
        customlog(
            f"market: purchase user={user_id} design={did} cost={cost} "
            f"charges={charges} goldArcori={avari.gold_arcori}"
        )
    return {
        "designId": did,
        "chargesRemaining": charges,
        "goldArcoriSpent": cost,
        "goldArcori": int(avari.gold_arcori),
        "goldFragments": int(avari.gold_fragments),
    }


def recharge_slammer(
    session: Session, *, user_id: str, design_id: str
) -> dict[str, Any]:
    did = (design_id or "").strip()
    if not did:
        raise AppError(INVALID_QUERY, message="designId required")
    if not is_market_slammer(did):
        raise AppError(NOT_FOR_SALE)

    design = _design_or_raise(did)
    eco = parse_slammer_economy(design)
    row = _owned_row(session, user_id, did)
    if row is None:
        raise AppError(NOT_OWNED)
    if bool(row.permanent):
        raise AppError(PERMANENT_NO_RECHARGE)

    avari = _ensure_avari(session, user_id)
    gold_a, gold_f = normalize_wallet(
        int(avari.gold_arcori), int(avari.gold_fragments)
    )
    cost = int(eco["rechargePriceGoldArcori"])
    add = int(eco["rechargeCharges"])
    if gold_a < cost:
        raise AppError(
            INSUFFICIENT_GOLD,
            message=f"Need {cost} Gold Arcori to top up charges",
        )
    avari.gold_arcori = gold_a - cost
    avari.gold_fragments = gold_f
    before = int(row.charges_remaining or 0)
    row.charges_remaining = before + add
    session.flush()
    if LOGGING_SWITCH:
        customlog(
            f"market: recharge user={user_id} design={did} cost={cost} "
            f"+{add} charges={row.charges_remaining} goldArcori={avari.gold_arcori}"
        )
    return {
        "designId": did,
        "chargesAdded": add,
        "chargesRemaining": int(row.charges_remaining),
        "goldArcoriSpent": cost,
        "goldArcori": int(avari.gold_arcori),
        "goldFragments": int(avari.gold_fragments),
    }


def parse_design_id_body(body: dict[str, Any] | None) -> str:
    if not isinstance(body, dict):
        raise AppError(INVALID_QUERY, message="JSON body required")
    did = str(body.get("designId") or body.get("design_id") or "").strip()
    if not did:
        raise AppError(INVALID_QUERY, message="designId required")
    return did
