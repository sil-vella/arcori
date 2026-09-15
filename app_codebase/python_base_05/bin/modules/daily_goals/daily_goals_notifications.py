"""Daily goal / task completion notifications (instant celebrate + View)."""

from __future__ import annotations

from typing import Any

from core.notifications.response_types import RESPONSE_TYPE_NAVIGATE
from core.notifications.subtype_registry import register_notification_subtype
from core.notifications.subtype_spec import NotificationSubtypeSpec
from core.utils.dev_logger import customlog
from models.user_notification import NOTIFICATION_TYPE_INSTANT
from modules.notifications.notification_service import create_for_user

DAILY_GOALS_SOURCE = "daily_goals"
DAILY_GOALS_CATEGORY = "progress"
DAILY_GOALS_COMPLETE_SUBTYPE = "complete_v1"

LOGGING_SWITCH = True


def daily_complete_msg_id(
    *, user_id: str, goal_id: str, day_key: str
) -> str:
    return f"daily_complete:{user_id}:{goal_id}:{day_key}"


def register_daily_goals_notification_subtypes() -> None:
    register_notification_subtype(
        NotificationSubtypeSpec(
            source=DAILY_GOALS_SOURCE,
            category=DAILY_GOALS_CATEGORY,
            subtype=DAILY_GOALS_COMPLETE_SUBTYPE,
            default_delivery=NOTIFICATION_TYPE_INSTANT,
            allowed_response_types=frozenset({RESPONSE_TYPE_NAVIGATE}),
            allowed_screens=frozenset(
                {"tasks", "daily_goals", "achievements", "home", "play"}
            ),
            modal_priority=45,
        )
    )


def notify_daily_completions(
    *,
    user_id: str,
    day_key: str,
    completed_rows: list[dict[str, Any]],
) -> int:
    """Create one instant notification per newly completed daily/task. Soft-fails."""
    created = 0
    day = (day_key or "").strip() or "unknown"
    for row in completed_rows:
        if not isinstance(row, dict):
            continue
        gid = str(row.get("id") or "").strip()
        if not gid:
            continue
        name = str(row.get("name") or gid).strip()
        description = str(row.get("description") or "").strip()
        section = str(row.get("section") or "").strip().lower()
        action = row.get("postCompleteAction") or row.get("post_complete_action")
        screen = "tasks" if section != "daily_goals" else "tasks"
        cta = "View"
        if isinstance(action, dict):
            atype = str(action.get("type") or "").strip().lower()
            if atype == "move_to_screen" and str(action.get("screen") or "").strip():
                screen = str(action.get("screen")).strip()
            label = str(action.get("ctaLabel") or action.get("cta_label") or "").strip()
            if label:
                cta = label
        title = (
            "Daily goal complete"
            if section == "daily_goals"
            else "Task complete"
        )
        try:
            create_for_user(
                user_id,
                source=DAILY_GOALS_SOURCE,
                notification_type=NOTIFICATION_TYPE_INSTANT,
                title=title,
                body=name if not description else f"{name} — {description}",
                category=DAILY_GOALS_CATEGORY,
                subtype=DAILY_GOALS_COMPLETE_SUBTYPE,
                msg_id=daily_complete_msg_id(
                    user_id=user_id, goal_id=gid, day_key=day
                ),
                data={
                    "goal": row,
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
                    f"daily_goals: notify complete soft-fail id={gid} err={exc}"
                )
    if LOGGING_SWITCH and created:
        customlog(
            f"daily_goals: notified completes user={user_id} "
            f"day={day} n={created}"
        )
    return created
