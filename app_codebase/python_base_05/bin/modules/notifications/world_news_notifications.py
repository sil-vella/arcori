"""World News notification subtypes + emitters (category=news)."""

from __future__ import annotations

import uuid
from typing import Any

from core.notifications.response_types import RESPONSE_TYPE_NAVIGATE
from core.notifications.subtype_registry import register_notification_subtype
from core.notifications.subtype_spec import NotificationSubtypeSpec
from core.utils.dev_logger import customlog
from models.user_notification import NOTIFICATION_TYPE_INBOX
from modules.notifications.notification_service import (
    create_for_user,
    upsert_global_news,
)

WORLD_SOURCE = "world"
WORLD_CATEGORY = "news"
ADMIN_SUBTYPE = "admin_v1"
GEN_CLOSED_SUBTYPE = "gen_closed_v1"
LEGACY_OWNER_SUBTYPE = "legacy_owner_v1"

LOGGING_SWITCH = True

_NEWS_NS = uuid.UUID("a7c0e9b1-4f2d-4c8a-9e11-00000000a001")


def register_world_news_notification_subtypes() -> None:
    screens = frozenset({"home", "museum", "velora", "notifications", "avari", "play"})
    navigate = frozenset({RESPONSE_TYPE_NAVIGATE})
    register_notification_subtype(
        NotificationSubtypeSpec(
            source=WORLD_SOURCE,
            category=WORLD_CATEGORY,
            subtype=ADMIN_SUBTYPE,
            default_delivery=NOTIFICATION_TYPE_INBOX,
            allowed_response_types=navigate,
            allowed_screens=screens,
            modal_priority=80,
        )
    )
    # Allow inbox (routine) or instant (critical) for generation closure.
    register_notification_subtype(
        NotificationSubtypeSpec(
            source=WORLD_SOURCE,
            category=WORLD_CATEGORY,
            subtype=GEN_CLOSED_SUBTYPE,
            default_delivery=None,
            allowed_response_types=navigate,
            allowed_screens=screens,
            modal_priority=70,
        )
    )
    register_notification_subtype(
        NotificationSubtypeSpec(
            source=WORLD_SOURCE,
            category=WORLD_CATEGORY,
            subtype=LEGACY_OWNER_SUBTYPE,
            default_delivery=NOTIFICATION_TYPE_INBOX,
            allowed_response_types=navigate,
            allowed_screens=screens,
            modal_priority=75,
        )
    )


def news_global_id_for_msg(msg_id: str) -> uuid.UUID:
    return uuid.uuid5(_NEWS_NS, str(msg_id).strip())


def _museum_response() -> dict[str, Any]:
    return {
        "type": "navigate",
        "buttons": [{"label": "Museum", "screen": "museum"}],
    }


def _home_response() -> dict[str, Any]:
    return {
        "type": "navigate",
        "buttons": [{"label": "Home", "screen": "home"}],
    }


def emit_gen_closed_news(
    *,
    design_id: str,
    generation_number: int,
    arcori_display_name: str,
    legacy_state: str,
) -> str | None:
    """Global World News when a generation closes (preserved or lost). Soft-fails."""
    did = (design_id or "").strip()
    if not did:
        return None
    gen = int(generation_number)
    name = (arcori_display_name or "").strip() or did
    state = (legacy_state or "").strip().lower() or "closed"
    msg_id = f"news_gen_closed_{did}_{gen}"
    title = f"Generation {gen} closed"
    if state == "preserved":
        body = f"{name} Gen {gen} was preserved and entered the Museum."
    elif state == "lost":
        body = f"{name} Gen {gen} closed without preservation."
    else:
        body = f"{name} Gen {gen} has left circulation."
    try:
        global_id = upsert_global_news(
            global_id=news_global_id_for_msg(msg_id),
            title=title,
            body=body,
            subtype=GEN_CLOSED_SUBTYPE,
            msg_id=msg_id,
            data={
                "designId": did,
                "generationNumber": gen,
                "legacyState": state,
                "arcoriDisplayName": name,
                "response": _museum_response(),
            },
        )
        if LOGGING_SWITCH:
            customlog(
                f"world_news: gen_closed design={did} gen={gen} global_id={global_id}"
            )
        return global_id
    except Exception as exc:  # noqa: BLE001 — never fail closure on news
        if LOGGING_SWITCH:
            customlog(f"world_news: gen_closed soft-fail err={exc}")
        return None


def emit_legacy_owner_news(
    *,
    user_id: str,
    design_id: str,
    generation_number: int,
    arcori_display_name: str,
    actor_display_name: str,
) -> dict[str, str | None]:
    """Per-user + global World News when a player earns Legacy Owner. Soft-fails."""
    uid = (user_id or "").strip()
    did = (design_id or "").strip()
    out: dict[str, str | None] = {"user_message_id": None, "global_id": None}
    if not uid or not did:
        return out
    gen = int(generation_number)
    arcori = (arcori_display_name or "").strip() or did
    actor = (actor_display_name or "").strip() or "An Avari"
    user_msg_id = f"news_legacy_owner_user_{uid}_{did}_{gen}"
    global_msg_id = f"news_legacy_owner_world_{did}_{gen}"
    title = "Legacy Owner"
    user_body = f"You preserved {arcori} Gen {gen} and earned Legacy Owner."
    world_body = f"{actor} became Legacy Owner of {arcori} Gen {gen}."

    try:
        out["user_message_id"] = create_for_user(
            uid,
            source=WORLD_SOURCE,
            notification_type=NOTIFICATION_TYPE_INBOX,
            title=title,
            body=user_body,
            category=WORLD_CATEGORY,
            subtype=LEGACY_OWNER_SUBTYPE,
            msg_id=user_msg_id,
            data={
                "designId": did,
                "generationNumber": gen,
                "arcoriDisplayName": arcori,
                "response": _home_response(),
            },
        )
    except Exception as exc:  # noqa: BLE001
        if LOGGING_SWITCH:
            customlog(f"world_news: legacy_owner user soft-fail err={exc}")

    try:
        out["global_id"] = upsert_global_news(
            global_id=news_global_id_for_msg(global_msg_id),
            title=title,
            body=world_body,
            subtype=LEGACY_OWNER_SUBTYPE,
            msg_id=global_msg_id,
            data={
                "designId": did,
                "generationNumber": gen,
                "arcoriDisplayName": arcori,
                "actorDisplayName": actor,
                "actorUserId": uid,
                "response": _museum_response(),
            },
        )
        if LOGGING_SWITCH:
            customlog(
                f"world_news: legacy_owner user={uid} design={did} gen={gen} "
                f"global={out['global_id']}"
            )
    except Exception as exc:  # noqa: BLE001
        if LOGGING_SWITCH:
            customlog(f"world_news: legacy_owner global soft-fail err={exc}")

    return out


def emit_world_news_for_closure_results(results: list[dict[str, Any]]) -> None:
    """Post-commit: emit news from preserve / lost-close result dicts."""
    for row in results:
        if not isinstance(row, dict) or not row.get("applied"):
            continue
        did = str(row.get("designId") or "").strip()
        if not did:
            continue
        try:
            gen = int(row.get("generationNumber") or 0)
        except (TypeError, ValueError):
            continue
        if gen < 1:
            continue
        arcori = str(row.get("arcoriDisplayName") or "").strip() or did
        state = str(row.get("legacyState") or "").strip().lower()
        emit_gen_closed_news(
            design_id=did,
            generation_number=gen,
            arcori_display_name=arcori,
            legacy_state=state or "closed",
        )
        if state == "preserved" or str(row.get("reason") or "") == "preserved":
            uid = str(
                row.get("preservedUserId")
                or row.get("userId")
                or ""
            ).strip()
            actor = str(row.get("actorDisplayName") or "").strip() or "An Avari"
            if uid:
                emit_legacy_owner_news(
                    user_id=uid,
                    design_id=did,
                    generation_number=gen,
                    arcori_display_name=arcori,
                    actor_display_name=actor,
                )
