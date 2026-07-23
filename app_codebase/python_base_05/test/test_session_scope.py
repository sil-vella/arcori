"""Tests for session_scope commit/rollback behavior."""

from __future__ import annotations

from unittest.mock import MagicMock

import pytest

from core.state.session_scope import session_scope


def test_session_scope_commits_on_success(monkeypatch):
    session = MagicMock()

    def _get_session():
        return session

    monkeypatch.setattr("core.state.session_scope.get_session", _get_session)

    with session_scope() as s:
        assert s is session
        s.add("row")

    session.commit.assert_called_once()
    session.rollback.assert_not_called()
    session.close.assert_called_once()


def test_session_scope_rolls_back_on_error(monkeypatch):
    session = MagicMock()
    monkeypatch.setattr("core.state.session_scope.get_session", lambda: session)

    with pytest.raises(RuntimeError):
        with session_scope():
            raise RuntimeError("boom")

    session.rollback.assert_called_once()
    session.commit.assert_not_called()
    session.close.assert_called_once()
