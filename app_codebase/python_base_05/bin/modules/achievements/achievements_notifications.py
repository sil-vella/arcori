"""Achievement unlock notifications (instant celebrate + View navigate)."""

from __future__ import annotations

from typing import Any

from core.notifications.response_types import RESPONSE_TYPE_NAVIGATE
from core.notifications.subtype_registry import register_notification_subtype
from core.notifications.subtype_spec import NotificationSubtypeSpec
from core.utils.dev_logger import customlog
from models.user_notification import NOTIFICATION_TYPE_INSTANT
from modules.notifications.notification_service import create_for_user

ACHIEVEMENT_SOURCE = "achievements"
ACHIEVEMENT_CATEGORY = "progress"
ACHIEVEMENT_UNLOCK_SUBTYPE = "unlock_v1"

LOGGING_SWITCH = True


def achievement_unlock_msg_id(
    *, user_id: str, achievement_id: str, match_id: str
) -> str:
    return f"achievement_unlock:{user_id}:{achievement_id}:{match_id}"


def register_achievement_notification_subtypes() -> None:
    register_notification_subtype(
        NotificationSubtypeSpec(
            source=ACHIEVEMENT_SOURCE,
            category=ACHIEVEMENT_CATEGORY,
            subtype=ACHIEVEMENT_UNLOCK_SUBTYPE,
            default_delivery=NOTIFICATION_TYPE_INSTANT,
            allowed_response_types=frozenset({RESPONSE_TYPE_NAVIGATE}),
            allowed_screens=frozenset(
                {"achievements", "avari", "tasks", "daily_goals", "home", "play"}
            ),
            modal_priority=40,
        )
    )


def notify_achievement_unlocks(
    *,
    user_id: str,
    match_id: str,
    unlocked_rows: list[dict[str, Any]],
) -> int:
    """Create one instant notification per newly unlocked achievement. Soft-fails."""
    created = 0
    mid = (match_id or "").strip() or "unknown"
    for row in unlocked_rows:
        if not isinstance(row, dict):
            continue
        aid = str(row.get("id") or "").strip()
        if not aid:
            continue
        name = str(
            row.get("achievementName") or row.get("achievement_name") or aid
        ).strip()
        description = str(row.get("description") or "").strip()
        action = row.get("postAchieveAction") or row.get("post_achieve_action")
        screen = "achievements"
        cta = "View"
        if isinstance(action, dict):
            atype = str(action.get("type") or "").strip().lower()
            if atype == "move_to_screen" and str(action.get("screen") or "").strip():
                screen = str(action.get("screen")).strip()
            label = str(action.get("ctaLabel") or action.get("cta_label") or "").strip()
            if label:
                cta = label
        try:
            create_for_user(
                user_id,
                source=ACHIEVEMENT_SOURCE,
                notification_type=NOTIFICATION_TYPE_INSTANT,
                title="Achievement unlocked",
                body=name if not description else f"{name} — {description}",
                category=ACHIEVEMENT_CATEGORY,
                subtype=ACHIEVEMENT_UNLOCK_SUBTYPE,
                msg_id=achievement_unlock_msg_id(
                    user_id=user_id, achievement_id=aid, match_id=mid
                ),
                data={
                    "achievement": row,
                    "response": {
                        "type": "navigate",
                        "buttons": [{"label": cta, "screen": screen}],
                    },
                },
            )
            created += 1
        except Exception as exc:  # noqa: BLE001 — never fail finalize on notify
            if LOGGING_SWITCH:
                customlog(
                    f"achievements: notify unlock soft-fail id={aid} err={exc}"
                )
    if LOGGING_SWITCH and created:
        customlog(
            f"achievements: notified unlocks user={user_id} "
            f"matchId={mid} n={created}"
        )
    return created
