"""World News subtype + emit helper unit tests."""

from __future__ import annotations

from unittest.mock import patch

from core.notifications.subtype_registry import (
    require_subtype_spec,
    reset_notification_subtypes,
)
from models.user_notification import NOTIFICATION_TYPE_INBOX
from modules.notifications.world_news_notifications import (
    ADMIN_SUBTYPE,
    GEN_CLOSED_SUBTYPE,
    LEGACY_OWNER_SUBTYPE,
    WORLD_CATEGORY,
    WORLD_SOURCE,
    emit_gen_closed_news,
    emit_legacy_owner_news,
    emit_world_news_for_closure_results,
    news_global_id_for_msg,
    register_world_news_notification_subtypes,
)


def setup_function() -> None:
    reset_notification_subtypes()
    register_world_news_notification_subtypes()


def test_world_news_subtypes_registered() -> None:
    for subtype in (ADMIN_SUBTYPE, GEN_CLOSED_SUBTYPE, LEGACY_OWNER_SUBTYPE):
        spec = require_subtype_spec(
            source=WORLD_SOURCE,
            category=WORLD_CATEGORY,
            subtype=subtype,
        )
        assert "home" in spec.allowed_screens
    admin = require_subtype_spec(
        source=WORLD_SOURCE,
        category=WORLD_CATEGORY,
        subtype=ADMIN_SUBTYPE,
    )
    assert admin.default_delivery == NOTIFICATION_TYPE_INBOX


def test_news_global_id_stable() -> None:
    a = news_global_id_for_msg("news_gen_closed_X_1")
    b = news_global_id_for_msg("news_gen_closed_X_1")
    assert a == b


def test_emit_gen_closed_calls_upsert() -> None:
    with patch(
        "modules.notifications.world_news_notifications.upsert_global_news",
        return_value="gid-1",
    ) as upsert:
        out = emit_gen_closed_news(
            design_id="CMY-MHO-SER003-GEN001-0003",
            generation_number=1,
            arcori_display_name="Many Hands, One Roof",
            legacy_state="preserved",
        )
    assert out == "gid-1"
    assert upsert.called
    kwargs = upsert.call_args.kwargs
    assert kwargs["subtype"] == GEN_CLOSED_SUBTYPE
    assert "Many Hands" in kwargs["body"]


def test_emit_legacy_owner_user_and_global() -> None:
    with (
        patch(
            "modules.notifications.world_news_notifications.create_for_user",
            return_value="uid-msg",
        ) as create,
        patch(
            "modules.notifications.world_news_notifications.upsert_global_news",
            return_value="gid-2",
        ) as upsert,
    ):
        out = emit_legacy_owner_news(
            user_id="11111111-1111-1111-1111-111111111111",
            design_id="DES-001",
            generation_number=2,
            arcori_display_name="Tiger",
            actor_display_name="Avari One",
        )
    assert out["user_message_id"] == "uid-msg"
    assert out["global_id"] == "gid-2"
    assert create.called and upsert.called


def test_emit_closure_results_preserved() -> None:
    with (
        patch(
            "modules.notifications.world_news_notifications.emit_gen_closed_news"
        ) as gen,
        patch(
            "modules.notifications.world_news_notifications.emit_legacy_owner_news"
        ) as owner,
    ):
        emit_world_news_for_closure_results(
            [
                {
                    "applied": True,
                    "designId": "DES-001",
                    "generationNumber": 1,
                    "legacyState": "preserved",
                    "reason": "preserved",
                    "arcoriDisplayName": "Tiger",
                    "preservedUserId": "11111111-1111-1111-1111-111111111111",
                    "actorDisplayName": "Host",
                }
            ]
        )
    assert gen.called
    assert owner.called
