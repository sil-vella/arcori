"""Legacy preserve business logic — lifecycle, checkout intent, fulfill, tick."""

from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy.exc import IntegrityError

from core.errors.app_error import AppError
from core.state.session_scope import session_scope
from core.utils.dev_logger import customlog
from models.avari_profile import AvariProfile
from models.legacy_preserve import (
    LEGACY_LOST,
    LEGACY_PRESERVED,
    PHASE_FIRST_OFFER,
    PHASE_LEADER_WINDOW,
    PHASE_LOST_CLOSED,
    PHASE_PRESERVED,
    PHASE_RACING,
)
from modules.avari.avari_service import (
    generation_number_for_design_id,
    mint_reach_or_series_default,
)
from modules.catalog.catalog_service import get_design
from modules.legacy import legacy_repository as repo
from modules.legacy.legacy_errors import (
    ALREADY_CLOSED,
    INTENT_NOT_FOUND,
    INVALID_FULFILL,
    INVALID_QUERY,
    MUSEUM_NOT_FOUND,
    NOT_ELIGIBLE,
    NOT_LEADER,
    OFFER_EXPIRED,
    PROCESSING,
)

LOGGING_SWITCH = True

# TEST TUNING — revert to days before ship (prod: 7d / 30d).
FIRST_OFFER_MINUTES = 5
LEADER_HOLD_MINUTES = 10
# Notify once per gap when a challenger closes to within this many of the leader.
LEADER_PROXIMITY_POINTS = 5
TITLE_LEGACY_OWNER = "Legacy Owner"
TITLE_GENERATION_CREATOR = "Generation Creator"
TITLE_MASTER = "Master"


def _closure_milestone_for_design(design: dict[str, Any] | None) -> int:
    if not isinstance(design, dict):
        return 1000
    legacy = design.get("legacy") if isinstance(design.get("legacy"), dict) else {}
    raw = legacy.get("closureMilestone")
    try:
        return max(1, int(raw))
    except (TypeError, ValueError):
        return 1000


def _thresholds(design_id: str) -> tuple[int, int]:
    design = None
    try:
        design = get_design(design_id)
    except Exception:
        design = None
    if not isinstance(design, dict):
        design = None
    return mint_reach_or_series_default(design), _closure_milestone_for_design(design)


def _ensure_title(avari: AvariProfile, title: str) -> None:
    titles = list(avari.titles or [])
    if title not in titles:
        titles.append(title)
        avari.titles = titles
    if not (avari.primary_title or "").strip() or avari.primary_title == "Avari":
        if title in (TITLE_LEGACY_OWNER, TITLE_GENERATION_CREATOR, TITLE_MASTER):
            avari.primary_title = title


def _serialize_lifecycle(row: Any, *, viewer_user_id: str | None = None) -> dict[str, Any]:
    viewer = (viewer_user_id or "").strip()
    offer_uid = str(row.first_offer_user_id) if row.first_offer_user_id else None
    leader_uid = str(row.leader_user_id) if row.leader_user_id else None
    can_first = (
        row.phase == PHASE_FIRST_OFFER
        and offer_uid is not None
        and offer_uid == viewer
    )
    can_leader = False
    if row.phase == PHASE_LEADER_WINDOW and leader_uid == viewer and row.leader_since:
        from datetime import timedelta

        hold_ok = repo.utcnow() >= (
            row.leader_since + timedelta(minutes=LEADER_HOLD_MINUTES)
        )
        can_leader = hold_ok

    return {
        "designId": row.design_id,
        "serial": row.design_id,
        "generationNumber": int(row.generation_number),
        "phase": row.phase,
        "legacyState": row.legacy_state,
        "preservationRequirement": int(row.preservation_requirement),
        "closureMilestone": int(row.closure_milestone),
        "firstOfferUserId": offer_uid,
        "firstOfferExpiresAt": (
            row.first_offer_expires_at.isoformat()
            if row.first_offer_expires_at
            else None
        ),
        "leaderUserId": leader_uid,
        "leaderSince": row.leader_since.isoformat() if row.leader_since else None,
        "leaderWindowEndsAt": (
            row.leader_window_ends_at.isoformat()
            if row.leader_window_ends_at
            else None
        ),
        "canPreserveAsFirstOffer": can_first,
        "canPreserveAsLeader": can_leader,
        "preservedUserId": (
            str(row.preserved_user_id) if row.preserved_user_id else None
        ),
    }


def get_offer(user_id: str, design_id: str) -> dict[str, Any]:
    uid = (user_id or "").strip()
    did = (design_id or "").strip()
    if not uid or not did:
        raise AppError(INVALID_QUERY, message="designId is required")
    gen = generation_number_for_design_id(did)
    pres, clos = _thresholds(did)
    with session_scope() as session:
        row = repo.ensure_lifecycle(
            session,
            design_id=did,
            generation_number=gen,
            preservation_requirement=pres,
            closure_milestone=clos,
        )
        points = repo.get_mastery_points(session, uid, did, gen)
        out = _serialize_lifecycle(row, viewer_user_id=uid)
        out["viewerMasteryPoints"] = points
        return out


def decline_offer(user_id: str, body: dict[str, Any] | None) -> dict[str, Any]:
    uid = (user_id or "").strip()
    if not uid:
        raise AppError(INVALID_QUERY, message="Unauthorized")
    if not isinstance(body, dict):
        raise AppError(INVALID_QUERY, message="JSON body required")
    items = _parse_offer_items(body)
    if not items:
        raise AppError(INVALID_QUERY, message="designId or offers is required")

    last: dict[str, Any] | None = None
    declined: list[dict[str, Any]] = []
    with session_scope() as session:
        for did, gen in items:
            row = repo.get_lifecycle(session, did, gen)
            if row is None:
                raise AppError(NOT_ELIGIBLE, message="No active offer")
            if row.phase in (PHASE_PRESERVED, PHASE_LOST_CLOSED):
                raise AppError(ALREADY_CLOSED)
            if row.phase != PHASE_FIRST_OFFER:
                last = _serialize_lifecycle(row, viewer_user_id=uid)
                declined.append(last)
                continue
            if str(row.first_offer_user_id) != uid:
                raise AppError(NOT_ELIGIBLE, message="Not the offer holder")
            _enter_leader_window(session, row, uid)
            last = _serialize_lifecycle(row, viewer_user_id=uid)
            declined.append(last)
            if LOGGING_SWITCH:
                customlog(f"legacy: decline offer user={uid} design={did} gen={gen}")
        session.flush()
    out = last or {}
    out["declined"] = declined
    return out


def _parse_offer_items(body: dict[str, Any]) -> list[tuple[str, int]]:
    """Accept offers[], designIds(+generationNumbers), or single designId."""
    items: list[tuple[str, int]] = []
    raw_offers = body.get("offers")
    if isinstance(raw_offers, list) and raw_offers:
        for row in raw_offers:
            if not isinstance(row, dict):
                continue
            did = str(row.get("designId") or row.get("design_id") or "").strip()
            if not did:
                continue
            try:
                gen = int(
                    row.get("generationNumber")
                    or row.get("generation_number")
                    or generation_number_for_design_id(did)
                )
            except (TypeError, ValueError):
                gen = generation_number_for_design_id(did)
            items.append((did, gen))
        return items

    raw_ids = body.get("designIds") or body.get("design_ids")
    if isinstance(raw_ids, str) and raw_ids.strip():
        id_list = [p.strip() for p in raw_ids.split(",") if p.strip()]
    elif isinstance(raw_ids, list):
        id_list = [str(p).strip() for p in raw_ids if str(p).strip()]
    else:
        id_list = []

    raw_gens = body.get("generationNumbers") or body.get("generation_numbers")
    gen_list: list[int] = []
    if isinstance(raw_gens, str) and raw_gens.strip():
        for p in raw_gens.split(","):
            try:
                gen_list.append(int(p.strip()))
            except (TypeError, ValueError):
                gen_list.append(0)
    elif isinstance(raw_gens, list):
        for p in raw_gens:
            try:
                gen_list.append(int(p))
            except (TypeError, ValueError):
                gen_list.append(0)

    if id_list:
        for i, did in enumerate(id_list):
            gen = gen_list[i] if i < len(gen_list) and gen_list[i] >= 1 else (
                generation_number_for_design_id(did)
            )
            items.append((did, gen))
        return items

    did = str(body.get("designId") or body.get("design_id") or "").strip()
    if did:
        try:
            gen = int(
                body.get("generationNumber")
                or body.get("generation_number")
                or generation_number_for_design_id(did)
            )
        except (TypeError, ValueError):
            gen = generation_number_for_design_id(did)
        items.append((did, gen))
    return items


def preserve_start(user_id: str, body: dict[str, Any] | None) -> dict[str, Any]:
    """Start preserve for selected designs; unselected first-offers → leader window.

    Dev stub: no website checkout — immediately mints selected and returns
    a complete payload (same shape as fulfill + preserve/complete).
    """
    uid = (user_id or "").strip()
    if not uid:
        raise AppError(INVALID_QUERY, message="Unauthorized")
    if not isinstance(body, dict):
        raise AppError(INVALID_QUERY, message="JSON body required")
    items = _parse_offer_items(body)
    if not items:
        raise AppError(INVALID_QUERY, message="designId or offers is required")

    decline_items = _parse_offer_items(
        {
            "offers": body.get("declineOffers")
            or body.get("decline_offers")
            or body.get("remainingOffers")
            or body.get("remaining_offers")
            or [],
        }
    )
    # Ignore overlap — selected wins.
    selected_set = set(items)
    decline_items = [x for x in decline_items if x not in selected_set]

    with session_scope() as session:
        payload_items: list[dict[str, Any]] = []
        lives: list[Any] = []
        for did, gen in items:
            row = repo.get_lifecycle(session, did, gen)
            if row is None:
                raise AppError(NOT_ELIGIBLE)
            if row.phase in (PHASE_PRESERVED, PHASE_LOST_CLOSED):
                raise AppError(ALREADY_CLOSED)
            _assert_can_preserve(session, row, uid)
            lives.append(row)
            payload_items.append(
                {
                    "designId": did,
                    "serial": did,
                    "generationNumber": gen,
                }
            )

        # Unselected first-offer designs → leader window immediately.
        declined_out: list[dict[str, Any]] = []
        for did, gen in decline_items:
            row = repo.get_lifecycle(session, did, gen)
            if row is None:
                continue
            if row.phase == PHASE_FIRST_OFFER and str(row.first_offer_user_id) == uid:
                _enter_leader_window(session, row, uid)
                declined_out.append(_serialize_lifecycle(row, viewer_user_id=uid))
                if LOGGING_SWITCH:
                    customlog(
                        f"legacy: auto leader_window (unselected) "
                        f"user={uid} design={did} gen={gen}"
                    )

        first_did, first_gen = items[0]
        intent_id = f"lpi_{uuid.uuid4().hex}"
        order_id = f"dev_{uuid.uuid4().hex}"
        repo.insert_intent(
            session,
            intent_id=intent_id,
            user_id=uid,
            design_id=first_did,
            generation_number=first_gen,
            expires_at=repo.days_from_now(2),
            items=payload_items if len(payload_items) > 1 else None,
        )

        # External-site payload (not opened — returned for inspection / future wire).
        checkout_payload = {
            "intentId": intent_id,
            "userId": uid,
            "orderId": order_id,
            "returnUrl": "arcori://legacy-preserve-complete",
            "items": [
                {
                    "designId": did,
                    "serial": did,
                    "generationNumber": gen,
                }
                for did, gen in items
            ],
            "designId": first_did,
            "serial": first_did,
            "generationNumber": first_gen,
            "designIds": ",".join(d for d, _ in items),
            "serials": ",".join(d for d, _ in items),
            "generationNumbers": ",".join(str(g) for _, g in items),
        }

        # DEV STUB: mint now (skip website).
        minted: list[dict[str, Any]] = []
        for row, (did, gen) in zip(lives, items):
            # Re-fetch after any prior mint in this txn.
            life = repo.get_lifecycle(session, did, gen) or row
            minted.append(
                _apply_preserve_mint(
                    session,
                    user_id=uid,
                    design_id=did,
                    generation_number=gen,
                    life=life,
                )
            )

        first = minted[0]
        payload = {
            "status": "complete",
            "applied": True,
            "reason": "preserved",
            "stubComplete": True,
            "intentId": intent_id,
            "orderId": order_id,
            "checkoutUrl": None,
            "checkoutPayload": checkout_payload,
            "designId": first["designId"],
            "serial": first["designId"],
            "generationNumber": first["generationNumber"],
            "echoGenerationNumber": first.get("echoGenerationNumber"),
            "legacyState": first.get("legacyState"),
            "titlesGranted": first.get("titlesGranted") or [],
            "creatorAttributed": True,
            "mint": first.get("mint"),
            "items": minted,
            "mints": [
                m.get("mint") for m in minted if isinstance(m.get("mint"), dict)
            ],
            "offers": payload_items,
            "declined": declined_out,
        }
        repo.insert_fulfill(
            session,
            order_id=order_id,
            intent_id=intent_id,
            user_id=uid,
            design_id=str(first["designId"]),
            generation_number=int(first["generationNumber"]),
            response=payload,
        )
        intent = repo.get_intent(session, intent_id)
        if intent is not None:
            repo.mark_intent_fulfilled(session, intent)
        if LOGGING_SWITCH:
            customlog(
                f"legacy: preserve stub-complete user={uid} n={len(items)} "
                f"declined={len(declined_out)} intent={intent_id} "
                f"serials={[d for d, _ in items]}"
            )
        return payload


def _enter_leader_window(session: Any, row: Any, seed_leader_user_id: str) -> None:
    row.phase = PHASE_LEADER_WINDOW
    row.first_offer_expires_at = None
    now = repo.utcnow()
    uid = uuid.UUID(seed_leader_user_id)
    row.leader_user_id = uid
    row.leader_since = now
    row.leader_window_ends_at = repo.minutes_from_now(LEADER_HOLD_MINUTES)
    session.flush()
    if LOGGING_SWITCH:
        customlog(
            f"legacy: enter leader_window user={seed_leader_user_id} "
            f"design={row.design_id} gen={row.generation_number} "
            f"hold_min={LEADER_HOLD_MINUTES}"
        )


def _assert_can_preserve(session: Any, row: Any, user_id: str) -> None:
    from datetime import timedelta

    if row.phase == PHASE_FIRST_OFFER:
        if str(row.first_offer_user_id) != user_id:
            raise AppError(NOT_ELIGIBLE)
        if row.first_offer_expires_at and repo.utcnow() > row.first_offer_expires_at:
            raise AppError(OFFER_EXPIRED)
        return
    if row.phase == PHASE_LEADER_WINDOW:
        if str(row.leader_user_id) != user_id:
            raise AppError(NOT_LEADER)
        if row.leader_since is None:
            raise AppError(NOT_LEADER)
        if repo.utcnow() < (row.leader_since + timedelta(minutes=LEADER_HOLD_MINUTES)):
            raise AppError(
                NOT_LEADER,
                message=(
                    f"Must hold leadership for {LEADER_HOLD_MINUTES} minutes "
                    "before preserving"
                ),
            )
        return
    raise AppError(NOT_ELIGIBLE)


def preserve_complete(user_id: str, body: dict[str, Any] | None) -> dict[str, Any]:
    """Confirm mint after deep-link return — does not charge; reads fulfill ledger."""
    uid = (user_id or "").strip()
    if not uid:
        raise AppError(INVALID_QUERY, message="Unauthorized")
    if not isinstance(body, dict):
        raise AppError(INVALID_QUERY, message="JSON body required")
    intent_id = str(body.get("intentId") or "").strip()
    order_id = str(body.get("orderId") or "").strip()
    if not intent_id:
        raise AppError(INVALID_QUERY, message="intentId is required")

    with session_scope() as session:
        intent = repo.get_intent(session, intent_id)
        if intent is None or str(intent.user_id) != uid:
            raise AppError(INTENT_NOT_FOUND)
        row = None
        if order_id:
            row = repo.get_fulfill(session, order_id)
        if row is None:
            row = repo.get_fulfill_by_intent(session, intent_id)
        if row is None:
            # Soft processing — client may poll briefly (webhook race).
            return {
                "status": "processing",
                "applied": False,
                "reason": "processing",
                "intentId": intent_id,
                "orderId": order_id or None,
                "designId": intent.design_id,
                "generationNumber": int(intent.generation_number),
            }
        if str(row.user_id) != uid:
            raise AppError(INTENT_NOT_FOUND)
        payload = dict(row.response_json) if isinstance(row.response_json, dict) else {}
        payload.setdefault("orderId", row.order_id)
        payload.setdefault("intentId", intent_id)
        payload.setdefault("reason", "already_applied")
        payload["status"] = "complete"
        payload.setdefault("applied", True)
        return payload


def fulfill_from_website(body: dict[str, Any] | None) -> dict[str, Any]:
    """Service: website confirms paid order → mint all designs on the intent."""
    if not isinstance(body, dict):
        raise AppError(INVALID_FULFILL, message="JSON body required")
    order_id = str(body.get("orderId") or body.get("order_id") or "").strip()
    intent_id = str(body.get("intentId") or body.get("intent_id") or "").strip()
    user_id = str(body.get("userId") or body.get("user_id") or "").strip()
    if not order_id or not intent_id or not user_id:
        raise AppError(
            INVALID_FULFILL, message="orderId, intentId, userId required"
        )

    try:
        with session_scope() as session:
            existing = repo.get_fulfill(session, order_id)
            if existing is not None:
                cached = dict(existing.response_json) if isinstance(existing.response_json, dict) else {}
                cached["applied"] = False
                cached["reason"] = "already_applied"
                return cached

            intent = repo.get_intent(session, intent_id)
            if intent is None:
                raise AppError(INTENT_NOT_FOUND)
            if str(intent.user_id) != user_id:
                raise AppError(INVALID_FULFILL, message="intent user mismatch")

            items = _items_from_intent(intent)
            body_items = _parse_offer_items(body)
            if body_items and set(body_items) != set(items):
                raise AppError(
                    INVALID_FULFILL, message="intent design/gen mismatch"
                )
            elif not body_items:
                # Backward-compat single designId on fulfill body.
                did = str(body.get("designId") or body.get("design_id") or "").strip()
                if did:
                    try:
                        gen = int(
                            body.get("generationNumber")
                            or body.get("generation_number")
                            or 0
                        )
                    except (TypeError, ValueError):
                        raise AppError(
                            INVALID_FULFILL, message="generationNumber must be an int"
                        ) from None
                    if (did, gen) not in items:
                        raise AppError(
                            INVALID_FULFILL, message="intent design/gen mismatch"
                        )

            minted: list[dict[str, Any]] = []
            for did, gen in items:
                life = repo.get_lifecycle(session, did, gen)
                if life is None:
                    raise AppError(NOT_ELIGIBLE)
                if life.phase in (PHASE_PRESERVED, PHASE_LOST_CLOSED):
                    raise AppError(ALREADY_CLOSED)
                _assert_can_preserve(session, life, user_id)
                minted.append(
                    _apply_preserve_mint(
                        session,
                        user_id=user_id,
                        design_id=did,
                        generation_number=gen,
                        life=life,
                    )
                )

            first = minted[0]
            payload = {
                "applied": True,
                "reason": "preserved",
                "designId": first["designId"],
                "generationNumber": first["generationNumber"],
                "echoGenerationNumber": first.get("echoGenerationNumber"),
                "legacyState": first.get("legacyState"),
                "titlesGranted": first.get("titlesGranted") or [],
                "creatorAttributed": True,
                "mint": first.get("mint"),
                "items": minted,
                "mints": [m.get("mint") for m in minted if isinstance(m.get("mint"), dict)],
            }
            repo.insert_fulfill(
                session,
                order_id=order_id,
                intent_id=intent_id,
                user_id=user_id,
                design_id=str(first["designId"]),
                generation_number=int(first["generationNumber"]),
                response=payload,
            )
            repo.mark_intent_fulfilled(session, intent)
            if LOGGING_SWITCH:
                customlog(
                    f"legacy: fulfill order={order_id} intent={intent_id} "
                    f"user={user_id} n={len(items)} "
                    f"designs={[d for d, _ in items]}"
                )
            return payload
    except IntegrityError:
        with session_scope() as session:
            raced = repo.get_fulfill(session, order_id)
            if raced is not None:
                cached = dict(raced.response_json) if isinstance(raced.response_json, dict) else {}
                cached["applied"] = False
                cached["reason"] = "already_applied"
                return cached
        raise


def _items_from_intent(intent: Any) -> list[tuple[str, int]]:
    raw = getattr(intent, "items_json", None)
    if isinstance(raw, list) and raw:
        out: list[tuple[str, int]] = []
        for row in raw:
            if not isinstance(row, dict):
                continue
            did = str(row.get("designId") or row.get("design_id") or "").strip()
            if not did:
                continue
            try:
                gen = int(row.get("generationNumber") or row.get("generation_number") or 0)
            except (TypeError, ValueError):
                gen = 0
            if gen < 1:
                gen = generation_number_for_design_id(did)
            out.append((did, gen))
        if out:
            return out
    return [(str(intent.design_id), int(intent.generation_number))]


def _apply_preserve_mint(
    session: Any,
    *,
    user_id: str,
    design_id: str,
    generation_number: int,
    life: Any,
) -> dict[str, Any]:
    repo.insert_trove_mint(
        session,
        user_id=user_id,
        design_id=design_id,
        generation_number=generation_number,
        creator_attributed=True,
    )
    from sqlalchemy import select

    avari = session.scalars(
        select(AvariProfile).where(AvariProfile.user_id == uuid.UUID(user_id))
    ).first()
    if avari is not None:
        _ensure_title(avari, TITLE_LEGACY_OWNER)
        _ensure_title(avari, TITLE_GENERATION_CREATOR)

    now = repo.utcnow()
    life.phase = PHASE_PRESERVED
    life.legacy_state = LEGACY_PRESERVED
    life.preserved_user_id = uuid.UUID(user_id)
    life.closed_at = now

    actor_name = _display_name_for_user(session, user_id)
    arcori_name = _arcori_display_name(design_id)
    history = _museum_history_summary(
        legacy_state=LEGACY_PRESERVED,
        generation_number=generation_number,
        actor_display_name=actor_name,
        arcori_display_name=arcori_name,
    )
    repo.insert_museum(
        session,
        design_id=design_id,
        generation_number=generation_number,
        legacy_state=LEGACY_PRESERVED,
        preserved_user_id=user_id,
        meta={
            "creatorAttributed": True,
            "actorDisplayName": actor_name,
            "actorUserId": user_id,
            "actorRole": "legacy_owner",
            "arcoriDisplayName": arcori_name,
            "historySummary": history,
        },
    )

    echo = _echo_next_generation(
        session,
        closed_design_id=design_id,
        closed_generation_number=generation_number,
        life=life,
        creator_user_id=user_id,
    )

    return {
        "applied": True,
        "reason": "preserved",
        "designId": design_id,
        "serial": design_id,
        "generationNumber": generation_number,
        "echoGenerationNumber": echo["echoGenerationNumber"],
        "echoDesignId": echo["echoDesignId"],
        "legacyState": LEGACY_PRESERVED,
        "titlesGranted": [TITLE_LEGACY_OWNER, TITLE_GENERATION_CREATOR],
        "creatorAttributed": True,
        "mint": {
            "designId": design_id,
            "serial": design_id,
            "generationNumber": generation_number,
            "legacyTitle": TITLE_LEGACY_OWNER,
            "creatorAttributed": True,
        },
    }


def _apply_lost_close(
    session: Any,
    *,
    life: Any,
    design_id: str,
    generation_number: int,
    closer_user_id: str | None,
) -> dict[str, Any]:
    now = repo.utcnow()
    life.phase = PHASE_LOST_CLOSED
    life.legacy_state = LEGACY_LOST
    life.closed_at = now
    if closer_user_id:
        from sqlalchemy import select

        avari = session.scalars(
            select(AvariProfile).where(
                AvariProfile.user_id == uuid.UUID(closer_user_id)
            )
        ).first()
        if avari is not None:
            _ensure_title(avari, TITLE_MASTER)

    master_id = (closer_user_id or "").strip() or None
    actor_name = _display_name_for_user(session, master_id) if master_id else "Unknown"
    arcori_name = _arcori_display_name(design_id)
    history = _museum_history_summary(
        legacy_state=LEGACY_LOST,
        generation_number=generation_number,
        actor_display_name=actor_name,
        arcori_display_name=arcori_name,
    )
    repo.insert_museum(
        session,
        design_id=design_id,
        generation_number=generation_number,
        legacy_state=LEGACY_LOST,
        preserved_user_id=None,
        meta={
            "masterUserId": master_id,
            "actorDisplayName": actor_name,
            "actorUserId": master_id,
            "actorRole": "master",
            "arcoriDisplayName": arcori_name,
            "historySummary": history,
        },
    )
    echo = _echo_next_generation(
        session,
        closed_design_id=design_id,
        closed_generation_number=generation_number,
        life=life,
        creator_user_id=None,
    )
    return {
        "applied": True,
        "reason": "lost_closed",
        "designId": design_id,
        "generationNumber": generation_number,
        "echoGenerationNumber": echo["echoGenerationNumber"],
        "echoDesignId": echo["echoDesignId"],
        "legacyState": LEGACY_LOST,
        "creatorAttributed": False,
        "mint": None,
    }


def _echo_next_generation(
    session: Any,
    *,
    closed_design_id: str,
    closed_generation_number: int,
    life: Any,
    creator_user_id: str | None,
) -> dict[str, Any]:
    """Close catalog row, insert echo design in DB, open lifecycle, copy access."""
    from modules.catalog import catalog_repository as catalog_repo
    from modules.catalog.catalog_ids import (
        apply_generation_to_design_doc,
        with_generation,
    )

    next_gen = int(closed_generation_number) + 1
    try:
        echo_id = with_generation(closed_design_id, next_gen)
    except ValueError:
        # Legacy ids without parseable GEN — fall back to same id + gen column.
        echo_id = closed_design_id

    closed_row = catalog_repo.mark_closed(session, closed_design_id)
    series_key = (
        closed_row.series_key if closed_row is not None else "Unknown"
    )
    catalog_version = (
        closed_row.catalog_version if closed_row is not None else None
    )
    base_design: dict[str, Any] | None = None
    if closed_row is not None and isinstance(closed_row.design_json, dict):
        base_design = dict(closed_row.design_json)
    else:
        try:
            base_design = get_design(closed_design_id)
        except Exception:
            base_design = None

    if base_design is not None:
        creator = None
        if creator_user_id:
            creator = {"type": "player", "playerId": creator_user_id}
        else:
            creator = {"type": "system", "playerId": None}
        echo_design = apply_generation_to_design_doc(
            base_design,
            generation_number=next_gen,
            creator=creator,
        )
        # Only catalog field that changes between gens: approved disc accent.
        from modules.avari.kin_genesis import pick_echo_color

        echo_design["color"] = pick_echo_color(base_design.get("color"))
        echo_design["worldState"] = "Active"
        echo_design["internalId"] = echo_id
        catalog_repo.insert_echo(
            session,
            design=echo_design,
            series_key=series_key,
            parent_internal_id=closed_design_id,
            catalog_version=catalog_version,
        )

    repo.ensure_lifecycle(
        session,
        design_id=echo_id,
        generation_number=next_gen,
        preservation_requirement=int(life.preservation_requirement),
        closure_milestone=int(life.closure_milestone),
    )
    copied = catalog_repo.copy_design_access(
        session,
        from_design_id=closed_design_id,
        to_design_id=echo_id,
    )
    revoked = catalog_repo.revoke_all_access_for_design(
        session, closed_design_id
    )
    seeded = _seed_echo_mastery(
        session,
        closed_design_id=closed_design_id,
        closed_generation_number=int(closed_generation_number),
        echo_design_id=echo_id,
        echo_generation_number=next_gen,
        preservation_requirement=int(life.preservation_requirement),
        legacy_state=str(getattr(life, "legacy_state", "") or ""),
        closed_at=getattr(life, "closed_at", None),
    )
    if LOGGING_SWITCH:
        customlog(
            f"legacy: echo closed={closed_design_id} → {echo_id} "
            f"gen={next_gen} accessCopied={copied} accessRevoked={revoked} "
            f"masterySeeded={seeded}"
        )
    return {
        "echoDesignId": echo_id,
        "echoGenerationNumber": next_gen,
        "accessCopied": copied,
        "accessRevoked": revoked,
        "masterySeeded": seeded,
    }


def _seed_echo_mastery(
    session: Any,
    *,
    closed_design_id: str,
    closed_generation_number: int,
    echo_design_id: str,
    echo_generation_number: int,
    preservation_requirement: int,
    legacy_state: str = "",
    closed_at: Any | None = None,
) -> int:
    """Soft-reset seed + mastery-at-closure snapshots for all players on that gen.

    Closed mastery rows are left unchanged. Returns players who received a
    positive echo seed (snapshots count every player with closed mastery > 0).
    """
    from modules.avari import avari_repository as avari_repo
    from modules.avari.mastery_economy import echo_mastery_seed

    closed_id = (closed_design_id or "").strip()
    echo_id = (echo_design_id or "").strip()
    if not closed_id or not echo_id:
        return 0
    closed_gen = max(1, int(closed_generation_number))
    echo_gen = max(1, int(echo_generation_number))
    state = (legacy_state or "").strip().lower() or "lost"
    rows = avari_repo.list_mastery_for_design_generation(
        session,
        design_id=closed_id,
        generation_number=closed_gen,
    )
    seeded_players = 0
    for row in rows:
        closed_pts = int(getattr(row, "points", 0) or 0)
        if closed_pts <= 0:
            continue
        uid = getattr(row, "user_id", None)
        if uid is None:
            continue
        seed = echo_mastery_seed(
            closed_pts,
            preservation_requirement=preservation_requirement,
        )
        avari_repo.upsert_closed_generation(
            session,
            user_id=uid,
            design_id=closed_id,
            generation_number=closed_gen,
            mastery_points=closed_pts,
            legacy_state=state,
            echo_design_id=echo_id,
            echo_mastery_seeded=seed,
            echo_generation_number=echo_gen,
            closed_at=closed_at,
        )
        if seed <= 0:
            continue
        echo_row = avari_repo.ensure_mastery_row(
            session,
            user_id=uid,
            design_id=echo_id,
            generation_number=echo_gen,
            initial_points=seed,
        )
        if int(echo_row.points) < seed:
            echo_row.points = seed
            session.flush()
        avari_repo.ensure_design_access(
            session,
            user_id=str(uid),
            design_id=echo_id,
            source="echo",
        )
        seeded_players += 1
    return seeded_players


def _proximity_gaps_crossed(*, gap_before: int, gap_after: int) -> list[int]:
    """Integer gaps in 1..LEADER_PROXIMITY_POINTS that this mastery step crossed into.

    Example: before=7 after=3 → [5, 4, 3]. before=5 after=4 → [4].
    """
    if gap_after >= gap_before:
        return []
    out: list[int] = []
    for g in range(LEADER_PROXIMITY_POINTS, 0, -1):
        if gap_before > g >= gap_after:
            out.append(g)
    return out


def _arcori_display_name_from_design(
    design: dict[str, Any] | None, design_id: str
) -> str:
    if isinstance(design, dict):
        name = str(design.get("design") or "").strip()
        if name:
            return name[:80]
    return (design_id or "").strip() or "Arcori"


def on_mastery_progress(
    session: Any,
    *,
    user_id: str,
    design_id: str,
    generation_number: int,
    points_after: int,
    points_before: int | None = None,
) -> dict[str, Any] | None:
    """Called inside finalize txn after mastery write. Returns offer/mint event or None."""
    uid = (user_id or "").strip()
    did = (design_id or "").strip()
    if not uid or not did:
        return None
    gen = int(generation_number)
    pts = int(points_after)
    before = int(points_before) if points_before is not None else pts
    design = None
    try:
        design = get_design(did)
    except Exception:
        design = None
    if not isinstance(design, dict):
        design = None
    pres = mint_reach_or_series_default(design)
    clos = _closure_milestone_for_design(design)

    life = repo.ensure_lifecycle(
        session,
        design_id=did,
        generation_number=gen,
        preservation_requirement=pres,
        closure_milestone=clos,
    )
    if life.phase in (PHASE_PRESERVED, PHASE_LOST_CLOSED):
        return None

    # Auto-close at mastery cap before preserve.
    if pts >= int(life.closure_milestone) and life.phase not in (
        PHASE_PRESERVED,
        PHASE_LOST_CLOSED,
    ):
        lost = _apply_lost_close(
            session,
            life=life,
            design_id=did,
            generation_number=gen,
            closer_user_id=uid,
        )
        if LOGGING_SWITCH:
            customlog(
                f"legacy: auto-close lost design={did} gen={gen} user={uid} pts={pts}"
            )
        return {"legacyEvent": lost}

    # First offer claim (idempotent: only from racing).
    if life.phase == PHASE_RACING and pts >= int(life.preservation_requirement):
        life.phase = PHASE_FIRST_OFFER
        life.first_offer_user_id = uuid.UUID(uid)
        life.first_offer_expires_at = repo.minutes_from_now(FIRST_OFFER_MINUTES)
        life.leader_user_id = uuid.UUID(uid)
        life.leader_since = repo.utcnow()
        life.leader_window_ends_at = repo.minutes_from_now(LEADER_HOLD_MINUTES)
        session.flush()
        if LOGGING_SWITCH:
            customlog(
                f"legacy: first_offer user={uid} design={did} gen={gen} pts={pts} "
                f"expires_in_min={FIRST_OFFER_MINUTES}"
            )
        return {
            "legacyOffer": _serialize_lifecycle(life, viewer_user_id=uid),
        }

    # Leader updates during first_offer (others racing mastery) or leader_window.
    if life.phase in (PHASE_FIRST_OFFER, PHASE_LEADER_WINDOW):
        current_leader = str(life.leader_user_id) if life.leader_user_id else None
        if current_leader and current_leader != uid:
            leader_pts = repo.get_mastery_points(session, current_leader, did, gen)
            if pts > leader_pts:
                life.leader_user_id = uuid.UUID(uid)
                life.leader_since = repo.utcnow()
                life.leader_window_ends_at = repo.minutes_from_now(LEADER_HOLD_MINUTES)
                session.flush()
                if LOGGING_SWITCH:
                    customlog(
                        f"legacy: new leader user={uid} design={did} gen={gen} "
                        f"pts={pts} hold_min={LEADER_HOLD_MINUTES}"
                    )
                return {
                    "legacyLeaderChanged": _serialize_lifecycle(
                        life, viewer_user_id=uid
                    ),
                }

            # Leader-window proximity: one event per gap 5..1 crossed this step.
            if life.phase == PHASE_LEADER_WINDOW:
                gap_before = int(leader_pts) - before
                gap_after = int(leader_pts) - pts
                gaps = _proximity_gaps_crossed(
                    gap_before=gap_before, gap_after=gap_after
                )
                if gaps:
                    arcori = _arcori_display_name_from_design(design, did)
                    events = [
                        {
                            "designId": did,
                            "generationNumber": gen,
                            "gap": g,
                            "leaderUserId": current_leader,
                            "challengerUserId": uid,
                            "leaderPoints": int(leader_pts),
                            "challengerPoints": pts,
                            "arcoriDisplayName": arcori,
                        }
                        for g in gaps
                    ]
                    if LOGGING_SWITCH:
                        customlog(
                            f"legacy: proximity design={did} gen={gen} "
                            f"challenger={uid} leader={current_leader} "
                            f"gaps={gaps} before={gap_before} after={gap_after}"
                        )
                    return {"legacyProximity": events}
    return None


def tick_expire_offers() -> dict[str, Any]:
    """Expire 7d first offers → leader_window. Safe to call repeatedly."""
    expired = 0
    with session_scope() as session:
        for row in repo.list_open_first_offers(session):
            seed = (
                str(row.first_offer_user_id)
                if row.first_offer_user_id
                else str(row.leader_user_id or "")
            )
            if not seed:
                row.phase = PHASE_LEADER_WINDOW
                row.first_offer_expires_at = None
                expired += 1
                continue
            _enter_leader_window(session, row, seed)
            expired += 1
            if LOGGING_SWITCH:
                customlog(
                    f"legacy: expire first_offer design={row.design_id} "
                    f"gen={row.generation_number}"
                )
    return {"expiredOffers": expired}


def _display_name_for_user(session: Any, user_id: str | None) -> str:
    raw = (user_id or "").strip()
    if not raw:
        return "Unknown"
    try:
        uid = uuid.UUID(raw)
    except ValueError:
        return raw[:8]
    from sqlalchemy import select

    avari = session.scalars(
        select(AvariProfile).where(AvariProfile.user_id == uid)
    ).first()
    name = str(getattr(avari, "display_name", "") or "").strip() if avari else ""
    if name:
        return name
    return raw[:8]


def _arcori_display_name(design_id: str) -> str:
    """Catalog face name (`design`), never the serial/internal id when known."""
    did = (design_id or "").strip()
    if not did:
        return "Unknown"
    try:
        design = get_design(did)
    except Exception:
        design = None
    if isinstance(design, dict):
        name = str(
            design.get("design") or design.get("displayName") or ""
        ).strip()
        if name:
            return name
    return did


def _museum_history_summary(
    *,
    legacy_state: str,
    generation_number: int,
    actor_display_name: str,
    arcori_display_name: str | None = None,
) -> str:
    gen = int(generation_number)
    # Generation Creator title refers to the echo (closed gen + 1).
    creator_gen = gen + 1
    actor = (actor_display_name or "Unknown").strip() or "Unknown"
    piece = (arcori_display_name or "").strip() or "Arcori"
    if legacy_state == LEGACY_PRESERVED:
        return (
            f"{piece} closed Preserved by {actor} "
            f"— Legacy owner & generation {creator_gen} echoer"
        )
    return f"{piece} closed Lost — Master: {actor}"


def _encode_museum_cursor(closed_at: Any, row_id: uuid.UUID) -> str:
    iso = closed_at.isoformat() if hasattr(closed_at, "isoformat") else str(closed_at)
    return f"{iso}|{row_id}"


def _decode_museum_cursor(
    raw: str | None,
) -> tuple[Any | None, uuid.UUID | None]:
    text = (raw or "").strip()
    if not text or "|" not in text:
        return None, None
    iso, id_part = text.rsplit("|", 1)
    try:
        row_id = uuid.UUID(id_part.strip())
    except ValueError:
        return None, None
    from datetime import datetime

    try:
        closed_at = datetime.fromisoformat(iso.strip())
    except ValueError:
        return None, None
    return closed_at, row_id


def _serialize_museum_item(session: Any, row: Any) -> dict[str, Any]:
    design_id = str(row.design_id or "").strip()
    generation_number = int(row.generation_number)
    legacy_state = str(row.legacy_state or "").strip().lower()
    meta = dict(row.meta_json or {}) if isinstance(row.meta_json, dict) else {}

    display_name = str(meta.get("arcoriDisplayName") or "").strip()
    image_url = None
    color = None
    series_key = None
    theme = None
    try:
        design = get_design(design_id)
    except Exception:
        design = None
    if isinstance(design, dict):
        if not display_name:
            display_name = str(
                design.get("design") or design.get("displayName") or ""
            ).strip()
        image_url = design.get("imageUrl")
        color = design.get("color")
        series_key = design.get("seriesKey")
        theme = design.get("theme")
    if not display_name:
        display_name = design_id

    if legacy_state == LEGACY_PRESERVED:
        actor_user_id = (
            str(meta.get("actorUserId") or "").strip()
            or (str(row.preserved_user_id) if row.preserved_user_id else "")
            or None
        )
        actor_role = "legacy_owner"
    else:
        actor_user_id = (
            str(meta.get("actorUserId") or meta.get("masterUserId") or "").strip()
            or None
        )
        actor_role = "master"

    actor_display_name = str(meta.get("actorDisplayName") or "").strip()
    if not actor_display_name:
        actor_display_name = _display_name_for_user(session, actor_user_id)

    # Rebuild caption so list/detail always use Arcori name + gen-numbered title.
    history = _museum_history_summary(
        legacy_state=legacy_state,
        generation_number=generation_number,
        actor_display_name=actor_display_name,
        arcori_display_name=display_name,
    )

    closed_at = row.closed_at
    closed_iso = (
        closed_at.isoformat() if hasattr(closed_at, "isoformat") else str(closed_at)
    )

    return {
        "designId": design_id,
        "displayName": display_name,
        "generationNumber": generation_number,
        "legacyState": legacy_state,
        "closedAt": closed_iso,
        "actorUserId": actor_user_id,
        "actorDisplayName": actor_display_name,
        "actorRole": actor_role,
        "historySummary": history,
        "imageUrl": image_url if isinstance(image_url, str) else None,
        "color": color if isinstance(color, str) else None,
        "seriesKey": series_key if isinstance(series_key, str) else None,
        "theme": theme if isinstance(theme, str) else None,
        "id": str(row.id),
    }


def list_museum(
    *,
    outcome: str = "all",
    q: str | None = None,
    limit: int = 30,
    cursor: str | None = None,
) -> dict[str, Any]:
    """World Museum: closed Preserved + Lost generations, newest first."""
    outcome_raw = (outcome or "all").strip().lower()
    if outcome_raw not in ("all", "preserved", "lost"):
        raise AppError(INVALID_QUERY, message="outcome must be all|preserved|lost")
    legacy_state = None if outcome_raw == "all" else outcome_raw
    lim = max(1, min(100, int(limit)))
    needle = (q or "").strip()
    cursor_closed_at, cursor_id = _decode_museum_cursor(cursor)

    # When searching by display name, over-fetch then filter in memory.
    fetch_limit = lim + 1 if not needle else min(100, max(lim + 1, lim * 5))

    with session_scope() as session:
        rows = repo.list_museum_generations(
            session,
            legacy_state=legacy_state,
            design_id_contains=None,
            limit=fetch_limit,
            cursor_closed_at=cursor_closed_at,
            cursor_id=cursor_id,
        )
        items: list[dict[str, Any]] = []
        for row in rows:
            item = _serialize_museum_item(session, row)
            if needle:
                hay = f"{item.get('displayName', '')} {item.get('designId', '')}".lower()
                if needle.lower() not in hay:
                    continue
            items.append(item)
            if len(items) > lim:
                break

        next_cursor = None
        if len(items) > lim:
            items = items[:lim]
            last = items[-1]
            # Prefer DB row id from serialization.
            last_row = next(
                (r for r in rows if str(r.id) == str(last.get("id"))),
                None,
            )
            if last_row is not None:
                next_cursor = _encode_museum_cursor(last_row.closed_at, last_row.id)

        if LOGGING_SWITCH:
            customlog(
                f"legacy: list_museum outcome={outcome_raw} q={needle!r} "
                f"count={len(items)} next={bool(next_cursor)}"
            )
        return {"items": items, "nextCursor": next_cursor}


def get_museum_item(*, design_id: str, generation_number: int) -> dict[str, Any]:
    did = (design_id or "").strip()
    if not did:
        raise AppError(INVALID_QUERY, message="designId is required")
    try:
        gen = int(generation_number)
    except (TypeError, ValueError) as exc:
        raise AppError(INVALID_QUERY, message="generationNumber is required") from exc
    if gen < 1:
        raise AppError(INVALID_QUERY, message="generationNumber must be >= 1")

    with session_scope() as session:
        row = repo.get_museum_generation(
            session, design_id=did, generation_number=gen
        )
        if row is None:
            raise AppError(MUSEUM_NOT_FOUND)
        item = _serialize_museum_item(session, row)
        if LOGGING_SWITCH:
            customlog(
                f"legacy: get_museum_item design={did} gen={gen} "
                f"state={item.get('legacyState')}"
            )
        return item

