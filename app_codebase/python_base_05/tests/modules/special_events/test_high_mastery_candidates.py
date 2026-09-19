"""High-mastery circulation SE candidate pool (min_mastery_ratio)."""

from __future__ import annotations

from unittest.mock import MagicMock

import pytest

from modules.special_events.special_events_service import build_candidate_ids_for_user
from modules.special_events.special_events_types import ARCORI_SOURCE_CIRCULATION


def _event(ratio: float = 0.8) -> dict:
    return {
        "id": "evt_high_mastery_v1",
        "arcori": {
            "source": ARCORI_SOURCE_CIRCULATION,
            "min_mastery_ratio": ratio,
            "hard_pick": True,
            "series_ids": [],
            "generation_numbers": [],
            "region_codes": [],
            "design_ids": [],
        },
    }


def test_keeps_design_at_or_above_ratio(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        "modules.avari.avari_service.list_design_access_ids",
        lambda _uid: ["HI", "LO", "EDGE"],
    )
    monkeypatch.setattr(
        "modules.players.players_service.is_ai_user",
        lambda _uid: False,
    )
    monkeypatch.setattr(
        "modules.avari.avari_repository.mastery_points_by_design",
        lambda _session, _uid: {"HI": 800, "LO": 799, "EDGE": 800},
    )
    monkeypatch.setattr(
        "modules.catalog.catalog_select._resolve_design",
        lambda _did: {"legacy": {"preservationRequirement": 1000}},
    )
    monkeypatch.setattr(
        "modules.avari.avari_service.mint_reach_or_series_default",
        lambda _design: 1000,
    )

    out = build_candidate_ids_for_user(
        MagicMock(), user_id="human-1", event=_event(0.8)
    )
    assert out == ["HI", "EDGE"]


def test_drops_below_ceil_threshold(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        "modules.avari.avari_service.list_design_access_ids",
        lambda _uid: ["A"],
    )
    monkeypatch.setattr(
        "modules.players.players_service.is_ai_user",
        lambda _uid: False,
    )
    monkeypatch.setattr(
        "modules.avari.avari_repository.mastery_points_by_design",
        lambda _session, _uid: {"A": 799},
    )
    monkeypatch.setattr(
        "modules.catalog.catalog_select._resolve_design",
        lambda _did: {},
    )
    monkeypatch.setattr(
        "modules.avari.avari_service.mint_reach_or_series_default",
        lambda _design: 1000,
    )

    out = build_candidate_ids_for_user(
        MagicMock(), user_id="human-1", event=_event(0.8)
    )
    assert out == []


def test_human_empty_list_when_none_qualify(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        "modules.avari.avari_service.list_design_access_ids",
        lambda _uid: ["A", "B"],
    )
    monkeypatch.setattr(
        "modules.players.players_service.is_ai_user",
        lambda _uid: False,
    )
    monkeypatch.setattr(
        "modules.avari.avari_repository.mastery_points_by_design",
        lambda _session, _uid: {"A": 10, "B": 0},
    )
    monkeypatch.setattr(
        "modules.catalog.catalog_select._resolve_design",
        lambda _did: {},
    )
    monkeypatch.setattr(
        "modules.avari.avari_service.mint_reach_or_series_default",
        lambda _design: 500,
    )

    out = build_candidate_ids_for_user(
        MagicMock(), user_id="human-1", event=_event(0.8)
    )
    assert out == []


def test_ai_falls_back_to_default_when_none_qualify(
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
        "modules.avari.avari_repository.mastery_points_by_design",
        lambda _session, _uid: {"STARTER": 0},
    )
    monkeypatch.setattr(
        "modules.catalog.catalog_select._resolve_design",
        lambda _did: {},
    )
    monkeypatch.setattr(
        "modules.avari.avari_service.mint_reach_or_series_default",
        lambda _design: 500,
    )

    out = build_candidate_ids_for_user(
        MagicMock(), user_id="ai-1", event=_event(0.8)
    )
    assert out is None


def test_bare_circulation_without_ratio_still_none(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        "modules.avari.avari_service.list_design_access_ids",
        lambda _uid: ["A"],
    )
    event = {
        "id": "evt_stub",
        "arcori": {
            "source": ARCORI_SOURCE_CIRCULATION,
            "min_mastery_ratio": None,
            "series_ids": [],
            "generation_numbers": [],
            "region_codes": [],
            "design_ids": [],
        },
    }
    out = build_candidate_ids_for_user(
        MagicMock(), user_id="human-1", event=event
    )
    assert out is None
