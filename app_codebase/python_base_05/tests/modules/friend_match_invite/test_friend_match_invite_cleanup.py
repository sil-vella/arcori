"""Friend match invite store + notification discard helpers."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from modules.friend_match_invite.friend_match_invite_notifications import (
    invite_notification_msg_id,
    prune_stale_invite_notifications_for_user,
)
from modules.friend_match_invite.friend_match_invite_store import (
    accept_invite,
    cancel_expired_invites,
    create_invite,
    decline_invite,
    get_invite,
    reset_friend_match_invites,
)


def setup_function() -> None:
    reset_friend_match_invites()


def test_invite_notification_msg_id() -> None:
    assert invite_notification_msg_id("abc") == "friend_match_invite:abc"


def test_decline_removes_invite() -> None:
    invite_id = create_invite(host_user_id="h1", invited_user_id="g1")
    decline_invite(invite_id=invite_id, user_id="g1")
    assert get_invite(invite_id) is None


def test_accept_keeps_invite_for_resolve() -> None:
    invite_id = create_invite(host_user_id="h1", invited_user_id="g1")
    accept_invite(invite_id=invite_id, user_id="g1")
    rec = get_invite(invite_id)
    assert rec is not None
    assert rec.status == "accepted"


def test_cancel_expired_returns_records(monkeypatch) -> None:
    invite_id = create_invite(host_user_id="h1", invited_user_id="g1")
    rec = get_invite(invite_id)
    assert rec is not None
    rec.expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
    expired = cancel_expired_invites()
    assert len(expired) == 1
    assert expired[0].invite_id == invite_id
    assert get_invite(invite_id) is None


def test_prune_keeps_waiting_invite(monkeypatch) -> None:
    invite_id = create_invite(host_user_id="h1", invited_user_id="g1")
    messages = [
        {
            "source": "friend_match_invite",
            "msg_id": invite_notification_msg_id(invite_id),
            "data": {"inviteId": invite_id},
        },
        {"source": "other", "msg_id": "x", "data": {}},
    ]
    kept = prune_stale_invite_notifications_for_user("g1", messages)
    assert len(kept) == 2


def test_prune_drops_missing_invite(monkeypatch) -> None:
    discarded: list[str] = []

    def _fake_discard(invite_id: str, *, user_id: str | None = None) -> int:
        discarded.append(invite_id)
        return 1

    monkeypatch.setattr(
        "modules.friend_match_invite.friend_match_invite_notifications.discard_invite_notification",
        _fake_discard,
    )
    messages = [
        {
            "source": "friend_match_invite",
            "msg_id": "friend_match_invite:dead",
            "data": {"inviteId": "dead"},
        },
        {"source": "other", "msg_id": "x", "data": {}},
    ]
    kept = prune_stale_invite_notifications_for_user("g1", messages)
    assert [m["source"] for m in kept] == ["other"]
    assert discarded == ["dead"]
