"""Legacy preserve-offer + leader-window proximity notifications."""

from __future__ import annotations

from typing import Any

from core.notifications.response_types import RESPONSE_TYPE_NAVIGATE
from core.notifications.subtype_registry import register_notification_subtype
from core.notifications.subtype_spec import NotificationSubtypeSpec
from core.state.session_scope import session_scope
from core.utils.dev_logger import customlog
from models.user_notification import NOTIFICATION_TYPE_INSTANT
from modules.notifications.notification_service import create_for_user

LEGACY_SOURCE = "legacy"
LEGACY_CATEGORY = "progress"
LEGACY_OFFER_SUBTYPE = "offer_v1"
LEGACY_PRESSURE_SUBTYPE = "pressure_v1"
LEGACY_CHASE_SUBTYPE = "chase_v1"

LOGGING_SWITCH = True


def legacy_offer_msg_id(*, user_id: str, match_id: str) -> str:
    return f"legacy_offer:{user_id}:{match_id}"


def legacy_pressure_msg_id(
    *,
    leader_user_id: str,
    design_id: str,
    generation_number: int,
    challenger_user_id: str,
    gap: int,
) -> str:
    return (
        f"legacy_leader_pressure:{leader_user_id}:{design_id}:"
        f"{int(generation_number)}:{challenger_user_id}:{int(gap)}"
    )


def legacy_chase_msg_id(
    *,
    challenger_user_id: str,
    design_id: str,
    generation_number: int,
    leader_user_id: str,
    gap: int,
) -> str:
    return (
        f"legacy_leader_chase:{challenger_user_id}:{design_id}:"
        f"{int(generation_number)}:{leader_user_id}:{int(gap)}"
    )


def register_legacy_notification_subtypes() -> None:
    register_notification_subtype(
        NotificationSubtypeSpec(
            source=LEGACY_SOURCE,
            category=LEGACY_CATEGORY,
            subtype=LEGACY_OFFER_SUBTYPE,
            default_delivery=NOTIFICATION_TYPE_INSTANT,
            allowed_response_types=frozenset({RESPONSE_TYPE_NAVIGATE}),
            allowed_screens=frozenset({"avari", "play", "home", "tasks"}),
            modal_priority=35,
        )
    )
    register_notification_subtype(
        NotificationSubtypeSpec(
            source=LEGACY_SOURCE,
            category=LEGACY_CATEGORY,
            subtype=LEGACY_PRESSURE_SUBTYPE,
            default_delivery=NOTIFICATION_TYPE_INSTANT,
            allowed_response_types=frozenset({RESPONSE_TYPE_NAVIGATE}),
            allowed_screens=frozenset({"play", "avari", "home"}),
            modal_priority=38,
        )
    )
    register_notification_subtype(
        NotificationSubtypeSpec(
            source=LEGACY_SOURCE,
            category=LEGACY_CATEGORY,
            subtype=LEGACY_CHASE_SUBTYPE,
            default_delivery=NOTIFICATION_TYPE_INSTANT,
            allowed_response_types=frozenset({RESPONSE_TYPE_NAVIGATE}),
            allowed_screens=frozenset({"play", "avari", "home"}),
            modal_priority=38,
        )
    )


def _player_display_name(user_id: str) -> str:
    uid = (user_id or "").strip()
    if not uid:
        return "Avari"
    try:
        from modules.avari import avari_repository as avari_repo

        with session_scope() as session:
            row = avari_repo.find_avari_profile(session, uid)
            name = (getattr(row, "display_name", None) or "").strip() if row else ""
            if name:
                return name[:64]
    except Exception:  # noqa: BLE001 — display name is best-effort
        pass
    return "Avari"


def _arcori_display_name(design_id: str) -> str:
    did = (design_id or "").strip()
    if not did:
        return "Arcori"
    try:
        from modules.catalog.catalog_service import get_design

        design = get_design(did)
        if isinstance(design, dict):
            name = str(design.get("design") or "").strip()
            if name:
                return name[:80]
    except Exception:  # noqa: BLE001
        pass
    return did


def _play_now_response() -> dict[str, Any]:
    return {
        "type": "navigate",
        "buttons": [{"label": "Play now", "screen": "play"}],
    }


def _proximity_data(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "legacyProximity": row,
        "response": _play_now_response(),
    }


def notify_legacy_offers(
    *,
    user_id: str,
    match_id: str,
    offers: list[dict[str, Any]],
) -> int:
    """One instant notification listing every design that opened a preserve offer.

    Soft-fails — never fails finalize.
    """
    uid = (user_id or "").strip()
    mid = (match_id or "").strip() or "unknown"
    clean: list[dict[str, Any]] = []
    for row in offers:
        if not isinstance(row, dict):
            continue
        did = str(row.get("designId") or "").strip()
        if not did:
            continue
        clean.append(row)
    if not uid or not clean:
        return 0

    names: list[str] = []
    for row in clean:
        did = str(row.get("designId") or "").strip()
        names.append(did)
    if len(names) == 1:
        title = "Legacy preserve available"
        body = f"{names[0]} reached the preservation threshold."
    else:
        title = f"Legacy preserve — {len(names)} Arcori"
        body = ", ".join(names[:5]) + ("…" if len(names) > 5 else "")

    try:
        create_for_user(
            uid,
            source=LEGACY_SOURCE,
            notification_type=NOTIFICATION_TYPE_INSTANT,
            title=title,
            body=body,
            category=LEGACY_CATEGORY,
            subtype=LEGACY_OFFER_SUBTYPE,
            msg_id=legacy_offer_msg_id(user_id=uid, match_id=mid),
            data={
                "legacyOffers": clean,
                "matchId": mid,
                "response": {
                    "type": "navigate",
                    "buttons": [{"label": "Open Avari", "screen": "avari"}],
                },
            },
        )
        if LOGGING_SWITCH:
            customlog(
                f"legacy: notified offer user={uid} matchId={mid} n={len(clean)}"
            )
        return 1
    except Exception as exc:  # noqa: BLE001 — never fail finalize on notify
        if LOGGING_SWITCH:
            customlog(f"legacy: notify offer soft-fail err={exc}")
        return 0


def notify_legacy_leader_proximity(
    *,
    events: list[dict[str, Any]],
) -> int:
    """Notify leader (pressure) + challenger (chase) for each gap 5..1 crossed.

    Soft-fails per message — never fails finalize. Returns count created.
    """
    created = 0
    for row in events:
        if not isinstance(row, dict):
            continue
        try:
            gap = int(row.get("gap") or 0)
        except (TypeError, ValueError):
            continue
        if gap < 1 or gap > 5:
            continue
        did = str(row.get("designId") or "").strip()
        leader_uid = str(row.get("leaderUserId") or "").strip()
        challenger_uid = str(row.get("challengerUserId") or "").strip()
        if not did or not leader_uid or not challenger_uid:
            continue
        try:
            gen = int(row.get("generationNumber") or 1)
        except (TypeError, ValueError):
            gen = 1

        arcori = str(row.get("arcoriDisplayName") or "").strip() or _arcori_display_name(
            did
        )
        challenger_name = str(row.get("challengerDisplayName") or "").strip() or (
            _player_display_name(challenger_uid)
        )
        leader_name = str(row.get("leaderDisplayName") or "").strip() or (
            _player_display_name(leader_uid)
        )
        pts_word = "point" if gap == 1 else "points"
        payload = {
            "designId": did,
            "generationNumber": gen,
            "gap": gap,
            "leaderUserId": leader_uid,
            "challengerUserId": challenger_uid,
            "leaderPoints": row.get("leaderPoints"),
            "challengerPoints": row.get("challengerPoints"),
            "arcoriDisplayName": arcori,
            "challengerDisplayName": challenger_name,
            "leaderDisplayName": leader_name,
        }

        # Leader: someone is nearing your mastery.
        try:
            create_for_user(
                leader_uid,
                source=LEGACY_SOURCE,
                notification_type=NOTIFICATION_TYPE_INSTANT,
                title="Mastery challenge",
                body=(
                    f"{challenger_name} is {gap} {pts_word} away from claiming "
                    f"master of '{arcori}'"
                ),
                category=LEGACY_CATEGORY,
                subtype=LEGACY_PRESSURE_SUBTYPE,
                msg_id=legacy_pressure_msg_id(
                    leader_user_id=leader_uid,
                    design_id=did,
                    generation_number=gen,
                    challenger_user_id=challenger_uid,
                    gap=gap,
                ),
                data=_proximity_data(payload),
            )
            created += 1
            if LOGGING_SWITCH:
                customlog(
                    f"legacy: notified pressure leader={leader_uid} "
                    f"challenger={challenger_uid} design={did} gap={gap}"
                )
        except Exception as exc:  # noqa: BLE001
            if LOGGING_SWITCH:
                customlog(f"legacy: notify pressure soft-fail err={exc}")

        # Challenger: you are nearing the leader.
        try:
            create_for_user(
                challenger_uid,
                source=LEGACY_SOURCE,
                notification_type=NOTIFICATION_TYPE_INSTANT,
                title="Mastery within reach",
                body=(
                    f"You are {gap} {pts_word} away from claiming master of "
                    f"'{arcori}' from {leader_name}"
                ),
                category=LEGACY_CATEGORY,
                subtype=LEGACY_CHASE_SUBTYPE,
                msg_id=legacy_chase_msg_id(
                    challenger_user_id=challenger_uid,
                    design_id=did,
                    generation_number=gen,
                    leader_user_id=leader_uid,
                    gap=gap,
                ),
                data=_proximity_data(payload),
            )
            created += 1
            if LOGGING_SWITCH:
                customlog(
                    f"legacy: notified chase challenger={challenger_uid} "
                    f"leader={leader_uid} design={did} gap={gap}"
                )
        except Exception as exc:  # noqa: BLE001
            if LOGGING_SWITCH:
                customlog(f"legacy: notify chase soft-fail err={exc}")

    return created
