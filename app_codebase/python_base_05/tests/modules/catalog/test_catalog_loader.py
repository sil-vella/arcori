"""Tests for catalog mtime-cached JSON loader."""

from __future__ import annotations

import json
import time
from pathlib import Path

import pytest

from modules.catalog import catalog_loader as loader


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
        "catalog": "Animals Test",
        "theme": "Animals",
        "themeCode": "ANM",
        "version": 1,
        "designs": [
            {
                "internalId": "ANM-TIG-GEN001-0001",
                "design": "Tiger",
                "theme": "Animals",
                "subtheme": "Big Cats",
                "themeCode": "ANM",
                "printedRarity": "Common",
                "series": "Genesis Series",
                "worldState": "Active",
                "seasonState": "Active",
                "artworkPrompt": "secret prompt",
                "loreDescription": "A tiger",
                "generation": {"roman": "I", "number": 1},
            }
        ],
    }
    (series / "Animals.json").write_text(json.dumps(animals), encoding="utf-8")
    loader.set_data_root_override(root)
    yield root
    loader.set_data_root_override(None)


def test_load_meta(catalog_root: Path):
    data = loader.load_meta("themes_subthemes")
    assert data["version"] == 1


def test_file_edit_visible_without_clear(catalog_root: Path):
    path = catalog_root / "series" / "001_test" / "Animals.json"
    doc = loader.load_json_file(path)
    assert doc["designs"][0]["design"] == "Tiger"

    time.sleep(0.02)
    doc["designs"][0]["design"] = "Tiger Updated"
    path.write_text(json.dumps(doc), encoding="utf-8")

    again = loader.load_json_file(path)
    assert again["designs"][0]["design"] == "Tiger Updated"


def test_new_theme_file_appears_in_listing(catalog_root: Path):
    paths = loader.list_theme_json_paths()
    assert any(p.name == "Animals.json" for p in paths)

    series = catalog_root / "series" / "001_test"
    time.sleep(0.02)
    fashion = {
        "catalog": "Fashion Test",
        "theme": "Fashion",
        "themeCode": "FSH",
        "version": 1,
        "designs": [{"internalId": "FSH-HAT-GEN001-0001", "design": "Hat"}],
    }
    (series / "Fashion.json").write_text(json.dumps(fashion), encoding="utf-8")

    paths2 = loader.list_theme_json_paths()
    names = {p.name for p in paths2}
    assert "Fashion.json" in names
    assert "Animals.json" in names

    codes = {d.get("themeCode") for d in loader.list_theme_documents()}
    assert "FSH" in codes
    assert "ANM" in codes


def test_find_by_theme_and_internal_id(catalog_root: Path):
    theme = loader.find_theme_document_by_code("anm")
    assert theme is not None
    assert theme["theme"] == "Animals"

    design = loader.find_design_by_internal_id("ANM-TIG-GEN001-0001")
    assert design is not None
    assert design["design"] == "Tiger"
    assert design.get("artworkPrompt") == "secret prompt"


def test_unknown_theme_and_design(catalog_root: Path):
    assert loader.find_theme_document_by_code("ZZZ") is None
    assert loader.find_design_by_internal_id("NOPE") is None
