"""Standings service unit tests (catalog fixture + in-process DB if available)."""

from __future__ import annotations

import json
import os
from pathlib import Path

import pytest

from core.errors.app_error import AppError
from modules.catalog import catalog_loader as loader
from modules.standings.standings_service import (
    clear_design_standings,
    get_design_standings,
    replace_design_standings,
)


@pytest.fixture
def catalog_root(tmp_path: Path):
    root = tmp_path / "data"
    series = root / "series" / "001_test"
    series.mkdir(parents=True)
    (root / "00_themes_subthemes.json").write_text(
        json.dumps({"version": 1, "themes": []}),
        encoding="utf-8",
    )
    (root / "01_regions.json").write_text(json.dumps({"regions": []}), encoding="utf-8")
    (root / "02_kin.json").write_text(json.dumps({"kin": []}), encoding="utf-8")
    (root / "03_printed_rarity.json").write_text(
        json.dumps({"rarities": []}),
        encoding="utf-8",
    )
    animals = {
        "catalog": "Animals Genesis Series",
        "theme": "Animals",
        "series": "Genesis",
        "themeCode": "ANM",
        "designs": [
            {
                "internalId": "ANM-TIG-GEN001-0001",
                "design": "Tiger",
                "theme": "Animals",
                "themeCode": "ANM",
                "series": "Genesis Series",
                "worldState": "Active",
                "generation": {"roman": "I", "number": 1},
            }
        ],
    }
    (series / "animals.json").write_text(json.dumps(animals), encoding="utf-8")
    loader.set_data_root_override(root)
    yield root
    loader.set_data_root_override(None)


def test_get_standings_unknown_design(catalog_root: Path):
    with pytest.raises(AppError) as exc:
        get_design_standings("MISSING-ID")
    assert exc.value.code == "catalog/not_found"


def test_get_standings_empty_without_db_row(catalog_root: Path):
    if not os.environ.get("DATABASE_URL", "").strip():
        pytest.skip("DATABASE_URL not set")
    payload = get_design_standings("ANM-TIG-GEN001-0001")
    assert payload["internalId"] == "ANM-TIG-GEN001-0001"
    assert payload["generation"]["number"] == 1
    assert payload["fill"] == {"current": 0, "cap": 0}
    assert payload["ranks"] == []


def test_replace_and_clear_standings(catalog_root: Path):
    if not os.environ.get("DATABASE_URL", "").strip():
        pytest.skip("DATABASE_URL not set")
    clear_design_standings("ANM-TIG-GEN001-0001", generation_number=1)
    replaced = replace_design_standings(
        "ANM-TIG-GEN001-0001",
        generation_number=1,
        generation_roman="I",
        fill_current=12,
        fill_cap=100,
        ranks=[
            {"rank": 1, "display_label": "Seed Player 1", "mastery_points": 90},
            {"rank": 2, "display_label": "Seed Player 2", "mastery_points": 40},
        ],
    )
    assert replaced["fill"]["current"] == 12
    assert len(replaced["ranks"]) == 2
    assert replaced["ranks"][0]["displayLabel"] == "Seed Player 1"

    got = get_design_standings("ANM-TIG-GEN001-0001")
    assert got["fill"]["cap"] == 100
    assert len(got["ranks"]) == 2

    clear_design_standings("ANM-TIG-GEN001-0001", generation_number=1)
    empty = get_design_standings("ANM-TIG-GEN001-0001")
    assert empty["ranks"] == []
    assert empty["fill"]["current"] == 0
