"""Tests for rematch invite create + accept."""

from __future__ import annotations

from modules.friend_match_invite.friend_match_invite_store import (
    accept_invite,
    create_rematch_invite,
    get_invite,
    reset_friend_match_invites,
)


def setup_function() -> None:
    reset_friend_match_invites()


def test_create_rematch_invite_stores_series_and_invitees() -> None:
    invite_id = create_rematch_invite(
        host_user_id="host-1",
        invited_user_ids=["guest-1", "ai-skip-me", "guest-2"],
        prior_match_id="m_abc_1",
        series_id="m_abc_1",
        series_index=2,
    )
    rec = get_invite(invite_id)
    assert rec is not None
    assert rec.kind == "rematch"
    assert rec.series_id == "m_abc_1"
    assert rec.series_index == 2
    assert rec.prior_match_id == "m_abc_1"
    assert rec.invited_user_ids == ["guest-1", "ai-skip-me", "guest-2"]
    assert rec.invited_user_id == "guest-1"


def test_accept_rematch_allows_each_invitee() -> None:
    invite_id = create_rematch_invite(
        host_user_id="host-1",
        invited_user_ids=["guest-1", "guest-2"],
        prior_match_id="m_abc_1",
        series_id="m_abc_1",
        series_index=2,
    )
    first = accept_invite(invite_id=invite_id, user_id="guest-1")
    assert first.status == "waiting"
    assert "guest-1" in first.accepted_user_ids

    second = accept_invite(invite_id=invite_id, user_id="guest-2")
    assert second.status == "accepted"
    assert set(second.accepted_user_ids) == {"guest-1", "guest-2"}


def test_create_rematch_allows_ai_only_invitees() -> None:
    invite_id = create_rematch_invite(
        host_user_id="host-1",
        invited_user_ids=["ai-user-1", "ai-user-2"],
        prior_match_id="m_abc_1",
        series_id="m_abc_1",
        series_index=2,
    )
    rec = get_invite(invite_id)
    assert rec is not None
    assert rec.kind == "rematch"
    assert rec.invited_user_ids == ["ai-user-1", "ai-user-2"]


def test_create_rematch_rejects_empty_invitees() -> None:
    try:
        create_rematch_invite(
            host_user_id="host-1",
            invited_user_ids=["host-1"],
            prior_match_id="m_abc_1",
            series_id="m_abc_1",
            series_index=2,
        )
        assert False, "expected ValueError"
    except ValueError:
        pass


def test_create_rematch_rejects_bad_series_index() -> None:
    try:
        create_rematch_invite(
            host_user_id="host-1",
            invited_user_ids=["guest-1"],
            prior_match_id="m_abc_1",
            series_id="m_abc_1",
            series_index=1,
        )
        assert False, "expected ValueError"
    except ValueError:
        pass
