"""Active-windows SE candidate pool for Preservation Chase."""

from __future__ import annotations

from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from modules.special_events.special_events_service import build_candidate_ids_for_user
from modules.special_events.special_events_types import ARCORI_SOURCE_ACTIVE_WINDOWS


def _event() -> dict:
    return {
        "id": "evt_active_window_v1",
        "arcori": {
            "source": ARCORI_SOURCE_ACTIVE_WINDOWS,
            "series_ids": [],
            "generation_numbers": [],
            "region_codes": [],
            "design_ids": [],
        },
    }


def test_human_candidates_are_access_intersect_open_windows(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        "modules.avari.avari_service.list_design_access_ids",
        lambda _uid: ["WIN-A", "WIN-B", "OTHER"],
    )
    monkeypatch.setattr(
        "modules.players.players_service.is_ai_user",
        lambda _uid: False,
    )
    monkeypatch.setattr(
        "modules.legacy.legacy_repository.list_open_preservation_windows",
        lambda _session: [
            SimpleNamespace(design_id="WIN-A"),
            SimpleNamespace(design_id="WIN-C"),
        ],
    )

    out = build_candidate_ids_for_user(
        MagicMock(), user_id="human-1", event=_event()
    )
    assert out == ["WIN-A"]


def test_ai_candidates_are_global_open_windows(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        "modules.avari.avari_service.list_design_access_ids",
        lambda _uid: ["STARTER-ONLY"],
    )
    monkeypatch.setattr(
        "modules.players.players_service.is_ai_user",
        lambda _uid: True,
    )
    monkeypatch.setattr(
        "modules.legacy.legacy_repository.list_open_preservation_windows",
        lambda _session: [
            SimpleNamespace(design_id="WIN-A"),
            SimpleNamespace(design_id="WIN-B"),
            SimpleNamespace(design_id="WIN-A"),
        ],
    )

    out = build_candidate_ids_for_user(
        MagicMock(), user_id="ai-1", event=_event()
    )
    assert out == ["WIN-A", "WIN-B"]


def test_human_empty_when_no_open_windows(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        "modules.avari.avari_service.list_design_access_ids",
        lambda _uid: ["WIN-A"],
    )
    monkeypatch.setattr(
        "modules.players.players_service.is_ai_user",
        lambda _uid: False,
    )
    monkeypatch.setattr(
        "modules.legacy.legacy_repository.list_open_preservation_windows",
        lambda _session: [],
    )

    out = build_candidate_ids_for_user(
        MagicMock(), user_id="human-1", event=_event()
    )
    assert out == []


def test_ai_falls_back_to_default_access_when_no_open_windows(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        "modules.avari.avari_service.list_design_access_ids",
        lambda _uid: ["STARTER"],
    )
    monkeypatch.setattr(
        "modules.players.players_service.is_ai_user",
        lambda _uid: True,
    )
    monkeypatch.setattr(
        "modules.legacy.legacy_repository.list_open_preservation_windows",
        lambda _session: [],
    )

    out = build_candidate_ids_for_user(
        MagicMock(), user_id="ai-1", event=_event()
    )
    assert out is None
