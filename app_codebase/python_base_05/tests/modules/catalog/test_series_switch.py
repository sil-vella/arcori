"""Series circulation switch (03_series.json) — master gate + Kin resolution."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from modules.catalog import catalog_loader as loader
from modules.catalog.catalog_select import _is_circulating
from modules.catalog.catalog_service import get_series
from modules.catalog.current_series import (
    design_series_is_active,
    list_series_catalog,
    resolve_design_series_key,
    series_is_active,
)


def _series_doc(*, genesis=True, pioneers=True, kin=False, creation=False) -> dict:
    return {
        "catalog": "Series Circulation Switch",
        "version": 1,
        "series": [
            {
                "key": "creation",
                "label": "Creation",
                "seriesKey": "Creation",
                "idToken": "SER000",
                "active": creation,
            },
            {
                "key": "genesis",
                "label": "Genesis",
                "seriesKey": "Genesis",
                "idToken": "SER001",
                "active": genesis,
            },
            {
                "key": "pioneers",
                "label": "Pioneers",
                "seriesKey": "Pioneers",
                "idToken": "SER002",
                "active": pioneers,
            },
            {
                "key": "foundations",
                "label": "Foundations",
                "seriesKey": "Foundations",
                "idToken": "SER003",
                "active": False,
            },
            {
                "key": "civilizations",
                "label": "Civilizations",
                "seriesKey": "Civilizations",
                "idToken": "SER004",
                "active": False,
            },
            {
                "key": "kin",
                "label": "Kin",
                "seriesKey": "Kin",
                "idToken": "SER005",
                "active": kin,
            },
        ],
    }


@pytest.fixture
def series_root(tmp_path: Path):
    root = tmp_path / "data"
    root.mkdir(parents=True)
    (root / "00_themes_subthemes.json").write_text(
        json.dumps({"version": 1, "themes": []}), encoding="utf-8"
    )
    (root / "01_regions.json").write_text(json.dumps({"regions": []}), encoding="utf-8")
    (root / "02_kin.json").write_text(json.dumps({"kin": []}), encoding="utf-8")
    (root / "03_series.json").write_text(
        json.dumps(_series_doc()), encoding="utf-8"
    )
    (root / "04_selection_weights.json").write_text(
        json.dumps({"version": 1}), encoding="utf-8"
    )
    loader.set_data_root_override(root)
    yield root
    loader.set_data_root_override(None)


def test_launch_state_only_genesis_and_pioneers_active(series_root: Path):
    assert series_is_active("Genesis") is True
    assert series_is_active("genesis") is True
    assert series_is_active("Genesis Series") is True
    assert series_is_active("Pioneers") is True
    assert series_is_active("Creation") is False
    assert series_is_active("Foundations") is False
    assert series_is_active("Civilizations") is False
    assert series_is_active("Kin") is False
    assert series_is_active("unknown") is False
    assert series_is_active("") is False


def test_list_series_catalog_active_only(series_root: Path):
    all_rows = list_series_catalog()
    assert [r["key"] for r in all_rows] == [
        "creation",
        "genesis",
        "pioneers",
        "foundations",
        "civilizations",
        "kin",
    ]
    active = list_series_catalog(active_only=True)
    assert [r["key"] for r in active] == ["genesis", "pioneers"]
    velora = get_series()
    assert [r["key"] for r in velora["series"]] == ["genesis", "pioneers"]


def test_missing_series_file_means_inactive(tmp_path: Path):
    root = tmp_path / "empty"
    root.mkdir()
    loader.set_data_root_override(root)
    try:
        assert series_is_active("Genesis") is False
        assert list_series_catalog(active_only=True) == []
    finally:
        loader.set_data_root_override(None)


def test_both_gates_required_for_circulating(series_root: Path):
    genesis_active = {
        "internalId": "ANM-TIG-SER001-GEN001-0001",
        "series": "Genesis Series",
        "worldState": "Active",
    }
    genesis_closed = {
        **genesis_active,
        "worldState": "Closed",
    }
    foundations_active = {
        "internalId": "LAW-ABC-SER003-GEN001-0001",
        "series": "Foundations Series",
        "worldState": "Active",
    }
    assert _is_circulating(genesis_active) is True
    assert _is_circulating(genesis_closed) is False
    assert _is_circulating(foundations_active) is False
    assert design_series_is_active(foundations_active) is False


def test_kin_resolves_as_kin_not_genesis_stamp(series_root: Path):
    kin_doc = {
        "internalId": "KIN-ADMIN-SER005-GEN001-0001",
        "theme": "Kin",
        "themeCode": "KIN",
        "series": "Genesis Series",
        "worldState": "Active",
    }
    assert resolve_design_series_key(kin_doc) == "Kin"
    assert design_series_is_active(kin_doc) is False
    assert _is_circulating(kin_doc) is False

    (series_root / "03_series.json").write_text(
        json.dumps(_series_doc(kin=True)), encoding="utf-8"
    )
    loader.clear_caches()
    assert design_series_is_active(kin_doc) is True
    assert _is_circulating(kin_doc) is True


def test_production_series_json_launch_state():
    """Real data/03_series.json: only Genesis + Pioneers active."""
    loader.set_data_root_override(None)
    loader.clear_caches()
    assert series_is_active("Genesis") is True
    assert series_is_active("Pioneers") is True
    assert series_is_active("Creation") is False
    assert series_is_active("Foundations") is False
    assert series_is_active("Civilizations") is False
    assert series_is_active("Kin") is False
    keys = [r["key"] for r in list_series_catalog(active_only=True)]
    assert keys == ["genesis", "pioneers"]
