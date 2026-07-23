"""Register built-in and module notification subtype specs."""

from __future__ import annotations

from core.notifications.subtype_registry import register_notification_subtype
from core.notifications.subtype_spec import NotificationSubtypeSpec
from core.notifications.response_types import RESPONSE_TYPE_NAVIGATE, RESPONSE_TYPE_REPLY
from models.user_notification import NOTIFICATION_TYPE_INBOX, NOTIFICATION_TYPE_INSTANT


def register_builtin_notification_subtypes() -> None:
    register_notification_subtype(
        NotificationSubtypeSpec(
            source="global_broadcast",
            category="system",
            subtype="welcome",
            default_delivery=NOTIFICATION_TYPE_INSTANT,
            allowed_screens=frozenset({"example_module", "notifications"}),
            allowed_response_types=frozenset({RESPONSE_TYPE_NAVIGATE}),
            modal_priority=10,
        )
    )
    register_notification_subtype(
        NotificationSubtypeSpec(
            source="example_module",
            category="demo",
            subtype="example_navigate_demo",
            default_delivery=NOTIFICATION_TYPE_INSTANT,
            allowed_screens=frozenset({"notifications", "home"}),
            allowed_response_types=frozenset({RESPONSE_TYPE_NAVIGATE}),
            modal_priority=50,
        )
    )
    register_notification_subtype(
        NotificationSubtypeSpec(
            source="example_module",
            category="demo",
            subtype="example_reply_demo",
            default_delivery=NOTIFICATION_TYPE_INSTANT,
            allowed_response_types=frozenset({RESPONSE_TYPE_REPLY}),
            reply_option_keys=frozenset({"accept", "decline"}),
            modal_priority=60,
        )
    )
    register_notification_subtype(
        NotificationSubtypeSpec(
            source="example_module",
            category="record",
            subtype="example_record_saved",
            default_delivery=NOTIFICATION_TYPE_INBOX,
            allowed_response_types=frozenset(),
            modal_priority=200,
        )
    )
