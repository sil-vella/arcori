"""Match-time Arcori selection from 04_selection_weights.json."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from modules.catalog import catalog_loader as loader
from modules.catalog.catalog_select import (
    SOURCE_RANDOM_FALLBACK,
    SOURCE_WEIGHTED,
    select_for_seats,
)


def _weights_doc() -> dict:
    return {
        "version": 1,
        "pipeline": ["printedRarity", "regionStanding"],
        "combine": "multiply",
        "printedRarity": {
            "weights": {
                "Common": 3.0,
                "Uncommon": 2.0,
                "Rare": 1.2,
                "Epic": 0.8,
                "Legendary": 0.5,
                "Unique": None,
            },
            "missingPrintedRarity": 3.0,
            "nullWeightMeans": "exclude_from_weighted_pool",
        },
        "regionStanding": {
            "noSeatedRegionsMultiplier": 1.0,
            "unknownPairMultiplier": 1.0,
            "sameRegionMultiplier": 1.0,
            "aggregate": "max_multiplier",
            "pairs": {
                "ASH": {
                    "EVG": {"label": "Hostility", "value": -2, "multiplier": 2.5},
                    "MWB": {"label": "Affinity", "value": 2, "multiplier": 0.7},
                },
                "EVG": {
                    "ASH": {"label": "Hostility", "value": -2, "multiplier": 2.5},
                },
                "MWB": {
                    "ASH": {"label": "Affinity", "value": 2, "multiplier": 0.7},
                },
            },
        },
    }


@pytest.fixture
def select_root(tmp_path: Path):
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
    (root / "04_selection_weights.json").write_text(
        json.dumps(_weights_doc()),
        encoding="utf-8",
    )
    animals = {
        "catalog": "Animals Test",
        "theme": "Animals",
        "themeCode": "ANM",
        "version": 1,
        "designs": [
            {
                "internalId": "ASH-COMMON-1",
                "design": "Ash Common",
                "printedRarity": "Common",
                "worldState": "Active",
                "location": {"regionCode": "ASH"},
            },
            {
                "internalId": "EVG-COMMON-1",
                "design": "Everlight Common",
                "printedRarity": "Common",
                "worldState": "Active",
                "location": {"regionCode": "EVG"},
            },
            {
                "internalId": "MWB-COMMON-1",
                "design": "Moonwake Common",
                "printedRarity": "Common",
                "worldState": "Active",
                "location": {"regionCode": "MWB"},
            },
            {
                "internalId": "UNIQUE-1",
                "design": "Unique Piece",
                "printedRarity": "Unique",
                "worldState": "Active",
                "location": {"regionCode": "RBY"},
            },
        ],
    }
    (series / "Animals.json").write_text(json.dumps(animals), encoding="utf-8")
    loader.set_data_root_override(root)
    yield root
    loader.set_data_root_override(None)


def test_hostility_boosts_second_seat(select_root: Path, monkeypatch: pytest.MonkeyPatch):
    # Force deterministic weighted pick: always take highest weight.
    def fake_weighted(ids, weights):
        best = max(range(len(ids)), key=lambda i: weights[i])
        return ids[best]

    monkeypatch.setattr(
        "modules.catalog.catalog_select._weighted_pick",
        fake_weighted,
    )

    out = select_for_seats(
        [
            {
                "userId": "u1",
                "candidateIds": ["ASH-COMMON-1"],
            },
            {
                "userId": "u2",
                "candidateIds": ["EVG-COMMON-1", "MWB-COMMON-1"],
            },
        ]
    )
    picks = out["selections"]
    assert picks[0]["arcoriId"] == "ASH-COMMON-1"
    assert picks[0]["source"] == SOURCE_WEIGHTED
    # ASH seated → EVG hostility 2.5 beats MWB affinity 0.7
    assert picks[1]["arcoriId"] == "EVG-COMMON-1"
    assert picks[1]["source"] == SOURCE_WEIGHTED
    assert picks[1]["weight"] == pytest.approx(3.0 * 2.5)


def test_corrupt_weights_random_fallback(select_root: Path):
    (select_root / "04_selection_weights.json").write_text(
        "{not-json",
        encoding="utf-8",
    )
    loader.clear_caches()
    out = select_for_seats(
        [
            {
                "userId": "u1",
                "candidateIds": ["ASH-COMMON-1", "EVG-COMMON-1"],
            }
        ]
    )
    pick = out["selections"][0]
    assert pick["source"] == SOURCE_RANDOM_FALLBACK
    assert pick["arcoriId"] in {"ASH-COMMON-1", "EVG-COMMON-1"}
    assert "weights_load_failed" in str(pick.get("reason", ""))


def test_unique_only_pool_random_fallback(select_root: Path):
    out = select_for_seats(
        [
            {
                "userId": "u1",
                "candidateIds": ["UNIQUE-1"],
            }
        ]
    )
    pick = out["selections"][0]
    assert pick["arcoriId"] == "UNIQUE-1"
    assert pick["source"] == SOURCE_RANDOM_FALLBACK
    assert pick.get("reason") == "empty_weighted_pool"


def test_empty_player_access_no_catalog_fallback(select_root: Path):
    out = select_for_seats([{"userId": "u1", "candidateIds": []}])
    pick = out["selections"][0]
    assert pick["arcoriId"] == ""
    assert pick["source"] == SOURCE_RANDOM_FALLBACK
    assert pick.get("reason") == "empty_player_access"


def test_retired_access_filtered_out(select_root: Path):
    series = select_root / "series" / "001_test"
    doc = json.loads((series / "Animals.json").read_text(encoding="utf-8"))
    doc["designs"].append(
        {
            "internalId": "RETIRED-1",
            "design": "Retired",
            "printedRarity": "Common",
            "worldState": "Retired",
            "location": {"regionCode": "ASH"},
        }
    )
    (series / "Animals.json").write_text(json.dumps(doc), encoding="utf-8")
    loader.clear_caches()

    out = select_for_seats(
        [
            {
                "userId": "u1",
                "candidateIds": ["RETIRED-1"],
            }
        ]
    )
    pick = out["selections"][0]
    assert pick["arcoriId"] == ""
    assert pick.get("reason") == "empty_player_access"
