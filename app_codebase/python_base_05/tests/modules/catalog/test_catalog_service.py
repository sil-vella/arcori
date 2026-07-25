"""Catalog service unit tests."""

from __future__ import annotations

import json
import time
from pathlib import Path

import pytest

from core.errors.app_error import AppError
from modules.catalog import catalog_loader as loader
from modules.catalog.catalog_service import get_design, get_index, get_meta, get_theme


@pytest.fixture
def catalog_root(tmp_path: Path):
    root = tmp_path / "data"
    series = root / "series" / "001_test"
    series.mkdir(parents=True)
    (root / "00_themes_subthemes.json").write_text(
        json.dumps({"version": 1, "themes": [{"code": "ANM"}]}),
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
        "version": 1,
        "designs": [
            {
                "internalId": "ANM-TIG-GEN001-0001",
                "designCode": "TIG",
                "designFamily": "TIGER",
                "design": "Tiger",
                "theme": "Animals",
                "subtheme": "Big Cats",
                "themeCode": "ANM",
                "printedRarity": "Common",
                "series": "Genesis Series",
                "worldState": "Active",
                "seasonState": "Active",
                "type": "arcori",
                "artworkPrompt": "secret prompt",
                "loreDescription": "A tiger",
                "generation": {
                    "roman": "I",
                    "number": 1,
                    "creator": {"type": "system", "playerId": None},
                },
            }
        ],
    }
    (series / "Animals.json").write_text(json.dumps(animals), encoding="utf-8")
    loader.set_data_root_override(root)
    yield root
    loader.set_data_root_override(None)


def test_meta_and_index(catalog_root: Path):
    meta = get_meta()
    assert "themes_subthemes" in meta
    idx = get_index()
    assert idx["total"] == 1
    assert idx["items"][0]["internalId"] == "ANM-TIG-GEN001-0001"
    assert "artworkPrompt" not in idx["items"][0]
    assert idx["items"][0]["seriesKey"] == "Genesis"
    assert (
        idx["items"][0]["imageUrl"]
        == "/catalog-media/genesis/animals/ANM-TIG-GEN001-0001.webp"
    )


def test_theme_strips_artwork_prompt(catalog_root: Path):
    theme = get_theme("ANM")
    assert theme["themeCode"] == "ANM"
    assert "artworkPrompt" not in theme["designs"][0]
    assert theme["designs"][0]["loreDescription"] == "A tiger"
    assert theme["designs"][0]["seriesKey"] == "Genesis"
    assert (
        theme["designs"][0]["imageUrl"]
        == "/catalog-media/genesis/animals/ANM-TIG-GEN001-0001.webp"
    )


def test_design_strips_artwork_prompt(catalog_root: Path):
    design = get_design("ANM-TIG-GEN001-0001")
    assert design["design"] == "Tiger"
    assert "artworkPrompt" not in design
    assert design["seriesKey"] == "Genesis"
    assert design["imageUrl"] == "/catalog-media/genesis/animals/ANM-TIG-GEN001-0001.webp"


def test_not_found(catalog_root: Path):
    with pytest.raises(AppError) as exc:
        get_theme("ZZZ")
    assert exc.value.code == "catalog/not_found"

    with pytest.raises(AppError) as exc2:
        get_design("MISSING")
    assert exc2.value.code == "catalog/not_found"


def test_index_picks_up_new_theme_file(catalog_root: Path):
    assert get_index()["total"] == 1
    series = catalog_root / "series" / "001_test"
    time.sleep(0.02)
    (series / "Fashion.json").write_text(
        json.dumps(
            {
                "theme": "Fashion",
                "themeCode": "FSH",
                "series": "Genesis",
                "catalog": "Fashion Genesis Series",
                "designs": [
                    {
                        "internalId": "FSH-HAT-GEN001-0001",
                        "design": "Hat",
                        "theme": "Fashion",
                        "themeCode": "FSH",
                        "series": "Genesis Series",
                        "worldState": "Active",
                        "artworkPrompt": "hide me",
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    idx = get_index(circulating=True)
    ids = {item["internalId"] for item in idx["items"]}
    assert "FSH-HAT-GEN001-0001" in ids
    assert idx["total"] == 2
    fashion = next(i for i in idx["items"] if i["internalId"].startswith("FSH"))
    assert fashion["seriesKey"] == "Genesis"
    assert fashion["imageUrl"] == "/catalog-media/genesis/fashion/FSH-HAT-GEN001-0001.webp"
