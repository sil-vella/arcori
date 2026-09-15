"""Unit tests for achievements catalog loader + evaluators."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from modules.achievements.achievements_evaluators import (
    compute_new_unlock_ids,
    evaluate_entry,
)
from modules.achievements.achievements_loader import (
    clear_caches,
    load_achievements_document,
    set_data_root_override,
)
from modules.achievements.achievements_service import (
    apply_win_streak,
    client_achievement_row,
    get_catalog_payload,
)


@pytest.fixture()
def catalog_root(tmp_path: Path) -> Path:
    doc = {
        "schema_version": 1,
        "achievements": [
            {
                "id": "first_victory",
                "achievement_name": "First victory",
                "description": "Win once.",
                "achievement_type": "total_wins",
                "params": {"min": 1},
                "post_achieve_action": {"type": "none"},
            },
            {
                "id": "hot_hand",
                "achievement_name": "Hot hand",
                "description": "Streak 3.",
                "achievement_type": "win_streak",
                "params": {"min": 3},
                "post_achieve_action": {
                    "type": "move_to_screen",
                    "screen": "avari",
                    "cta_label": "View",
                },
            },
            {
                "id": "mastery_any",
                "achievement_name": "Mastery",
                "description": "12 pts.",
                "achievement_type": "mastery_points",
                "params": {"min": 12},
                "post_achieve_action": {"type": "none"},
            },
            {
                "id": "bad_type",
                "achievement_name": "Bad",
                "description": "skip",
                "achievement_type": "not_a_real_type",
                "params": {"min": 1},
                "post_achieve_action": {"type": "none"},
            },
        ],
    }
    (tmp_path / "achievements.json").write_text(
        json.dumps(doc), encoding="utf-8"
    )
    clear_caches()
    set_data_root_override(tmp_path)
    yield tmp_path
    set_data_root_override(None)
    clear_caches()


def test_loader_skips_unknown_type(catalog_root: Path):
    doc, rev = load_achievements_document()
    assert rev
    ids = [a["id"] for a in doc["achievements"]]
    assert "first_victory" in ids
    assert "bad_type" not in ids


def test_catalog_payload_camel(catalog_root: Path):
    payload = get_catalog_payload()
    assert payload["schemaVersion"] == 1
    assert payload["revision"]
    row = next(a for a in payload["achievements"] if a["id"] == "hot_hand")
    assert row["achievementName"] == "Hot hand"
    assert row["postAchieveAction"]["type"] == "move_to_screen"
    assert row["postAchieveAction"]["screen"] == "avari"
    assert row["postAchieveAction"]["ctaLabel"] == "View"


def test_evaluators_and_new_unlocks(catalog_root: Path):
    doc, _ = load_achievements_document()
    catalog = doc["achievements"]
    ctx = {
        "wins": 1,
        "matches_played": 1,
        "flips": 0,
        "win_streak_current": 3,
        "is_winner": True,
        "match_flags": set(),
        "mastery_after": {"ANM-TIG": 12},
    }
    unlocked = compute_new_unlock_ids(catalog, set(), ctx)
    assert unlocked == ["first_victory", "hot_hand", "mastery_any"]

    already = {"first_victory"}
    unlocked2 = compute_new_unlock_ids(catalog, already, ctx)
    assert unlocked2 == ["hot_hand", "mastery_any"]

    assert not evaluate_entry(
        {"achievement_type": "total_wins", "params": {"min": 5}},
        ctx,
    )


def test_total_flips_thresholds():
    first = {"achievement_type": "total_flips", "params": {"min": 1}}
    ten = {"achievement_type": "total_flips", "params": {"min": 10}}
    assert not evaluate_entry(first, {"flips": 0})
    assert evaluate_entry(first, {"flips": 1})
    assert not evaluate_entry(ten, {"flips": 9})
    assert evaluate_entry(ten, {"flips": 10})
    unlocked = compute_new_unlock_ids(
        [
            {"id": "first_flip", **first},
            {"id": "ten_flips", **ten},
        ],
        set(),
        {"flips": 10},
    )
    assert unlocked == ["first_flip", "ten_flips"]


def test_event_flips_and_arcori_cleared():
    flips_row = {
        "id": "evt_flips",
        "achievement_type": "event_flips",
        "params": {"event_id": "evt_stub_v1", "min": 5},
    }
    clear_row = {
        "id": "evt_clear",
        "achievement_type": "event_arcori_cleared",
        "params": {
            "event_id": "evt_stub_v1",
            "design_ids": ["A", "B"],
        },
    }
    ctx_partial = {
        "event_id": "evt_stub_v1",
        "event_progress": {
            "evt_stub_v1": {"flips": 4, "flippedDesignIds": ["A"]},
        },
    }
    assert not evaluate_entry(flips_row, ctx_partial)
    assert not evaluate_entry(clear_row, ctx_partial)

    ctx_done = {
        "event_id": "evt_stub_v1",
        "event_progress": {
            "evt_stub_v1": {"flips": 5, "flippedDesignIds": ["A", "B"]},
        },
    }
    assert evaluate_entry(flips_row, ctx_done)
    assert evaluate_entry(clear_row, ctx_done)
    assert compute_new_unlock_ids(
        [flips_row, clear_row], set(), ctx_done
    ) == ["evt_flips", "evt_clear"]


def test_apply_win_streak():
    assert apply_win_streak(current=2, best=5, won=True) == (3, 5)
    assert apply_win_streak(current=5, best=5, won=True) == (6, 6)
    assert apply_win_streak(current=4, best=4, won=False) == (0, 4)


def test_client_row_open_path():
    row = client_achievement_row(
        {
            "id": "x",
            "achievement_name": "X",
            "description": "d",
            "achievement_type": "total_wins",
            "params": {"min": 1},
            "post_achieve_action": {
                "type": "open_path",
                "to_path": "/play",
                "cta_label": "Play",
            },
        }
    )
    assert row["postAchieveAction"]["toPath"] == "/play"
