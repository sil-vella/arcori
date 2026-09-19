"""Match-time Arcori selection from 04_selection_weights.json."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from modules.catalog import catalog_loader as loader
from modules.catalog.catalog_select import (
    SOURCE_MAJORITY,
    SOURCE_RANDOM_FALLBACK,
    SOURCE_RANDOM_REGION,
    SOURCE_WEIGHTED,
    select_arena_for_arcori_ids,
    select_for_seats,
)


def _weights_doc() -> dict:
    return {
        "version": 2,
        "pipeline": ["selectionWeight", "regionStanding"],
        "combine": "multiply",
        "selectionWeight": {
            "min": 0.01,
            "max": 10.0,
            "missingSelectionWeight": 3.0,
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
                "selectionWeight": 3.0,
                "worldState": "Active",
                "location": {"regionCode": "ASH"},
            },
            {
                "internalId": "EVG-COMMON-1",
                "design": "Everlight Common",
                "selectionWeight": 3.0,
                "worldState": "Active",
                "location": {"regionCode": "EVG"},
            },
            {
                "internalId": "MWB-COMMON-1",
                "design": "Moonwake Common",
                "selectionWeight": 3.0,
                "worldState": "Active",
                "location": {"regionCode": "MWB"},
            },
            {
                "internalId": "UNIQUE-1",
                "design": "Unique Piece",
                "selectionWeight": 0.01,
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


def test_player_kin_access_stays_in_pool(
    select_root: Path, monkeypatch: pytest.MonkeyPatch
):
    """DB access ids must resolve via get_design (Kin), not static loader only."""
    kin_id = "KIN-ADMIN202609121230-SER001-0501"
    kin_doc = {
        "internalId": kin_id,
        "design": "Admin Kin",
        "selectionWeight": 3.0,
        "worldState": "Active",
        "theme": "Kin",
        "themeCode": "KIN",
        "location": {"regionCode": "ASH"},
        "faceMedia": "lottie",
        "lottieUrl": f"/media/kin/players/{kin_id}.json",
    }

    real_get = __import__(
        "modules.catalog.catalog_service", fromlist=["get_design"]
    ).get_design

    def get_design_with_kin(internal_id: str):
        if str(internal_id).strip() == kin_id:
            return dict(kin_doc)
        return real_get(internal_id)

    monkeypatch.setattr(
        "modules.catalog.catalog_select.get_design",
        get_design_with_kin,
    )

    def fake_weighted(ids, weights):
        assert kin_id in ids
        return kin_id

    monkeypatch.setattr(
        "modules.catalog.catalog_select._weighted_pick",
        fake_weighted,
    )

    out = select_for_seats(
        [
            {
                "userId": "u1",
                "candidateIds": ["ASH-COMMON-1", kin_id],
            }
        ]
    )
    pick = out["selections"][0]
    assert pick["arcoriId"] == kin_id
    assert pick["source"] == SOURCE_WEIGHTED


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


def test_lowest_weight_still_weighted(select_root: Path):
    """0.01 selectionWeight stays in the weighted pool (not excluded)."""
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
    assert pick["source"] == SOURCE_WEIGHTED
    assert pick["weight"] == pytest.approx(0.01)


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
            "selectionWeight": 3.0,
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


def _install_arenas(root: Path) -> None:
    (root / "01_regions.json").write_text(
        json.dumps(
            {
                "regions": [
                    {
                        "regionCode": "ASH",
                        "slug": "ashdrift-hill",
                        "arenas": [
                            {
                                "arenaId": "ARN-ASH-HIL001-0001",
                                "name": "Ashdrift Hill",
                            },
                            {
                                "arenaId": "ARN-ASH-HSP001-0001",
                                "name": "Hospital",
                            },
                        ],
                    },
                    {
                        "regionCode": "EVG",
                        "slug": "everlight-grove",
                        "arenas": [
                            {
                                "arenaId": "ARN-EVG-GRV001-0001",
                                "name": "Everlight Grove",
                            },
                        ],
                    },
                    {
                        "regionCode": "MWB",
                        "slug": "moonwake-bay",
                        "arenas": [
                            {
                                "arenaId": "ARN-MWB-BAY001-0001",
                                "name": "Moonwake Bay",
                            },
                        ],
                    },
                    {
                        "regionCode": "AMB",
                        "slug": "amberwild",
                        "arenas": [
                            {
                                "arenaId": "ARN-AMB-WLD001-0001",
                                "name": "Amberwild",
                            },
                        ],
                    },
                ]
            }
        ),
        encoding="utf-8",
    )
    loader.clear_caches()


def test_select_arena_majority_region(select_root: Path):
    import random

    _install_arenas(select_root)
    out = select_arena_for_arcori_ids(
        ["ASH-COMMON-1", "ASH-COMMON-1", "EVG-COMMON-1"],
        rng=random.Random(0),
    )
    assert out["source"] == SOURCE_MAJORITY
    assert out["regionCode"] == "ASH"
    assert out["arenaId"].startswith("ARN-ASH-")
    assert (
        out["imageUrl"]
        == f"/catalog-media/velora/arenas/ashdrift-hill/{out['arenaId']}.webp"
    )


def test_select_arena_all_different_picks_catalog_region(select_root: Path):
    import random

    _install_arenas(select_root)
    rng = random.Random(7)
    out = select_arena_for_arcori_ids(
        ["ASH-COMMON-1", "EVG-COMMON-1", "MWB-COMMON-1"],
        rng=rng,
    )
    assert out["source"] == SOURCE_RANDOM_REGION
    assert out["regionCode"] in {"ASH", "EVG", "MWB", "AMB"}
    assert out["imageUrl"].startswith("/catalog-media/velora/")
    assert out["imageUrl"].endswith(f"/{out['arenaId']}.webp")

    again = select_arena_for_arcori_ids(
        ["ASH-COMMON-1", "EVG-COMMON-1", "MWB-COMMON-1"],
        rng=random.Random(7),
    )
    assert again["arenaId"] == out["arenaId"]


def test_select_arena_no_catalog_arenas(select_root: Path):
    from core.errors.app_error import AppError

    with pytest.raises(AppError) as exc:
        select_arena_for_arcori_ids(["ASH-COMMON-1"])
    assert exc.value.code == "catalog/invalid_query"


def test_select_for_seats_excludes_already_chosen(
    select_root: Path, monkeypatch: pytest.MonkeyPatch
):
    """Later seats cannot reuse an Arcori already assigned earlier."""

    def fake_weighted(ids, weights):
        # Prefer ASH-COMMON-1 when available so seat 0 takes it; seat 1 must not.
        if "ASH-COMMON-1" in ids:
            return "ASH-COMMON-1"
        return ids[0]

    monkeypatch.setattr(
        "modules.catalog.catalog_select._weighted_pick",
        fake_weighted,
    )
    out = select_for_seats(
        [
            {"userId": "u1", "candidateIds": ["ASH-COMMON-1", "EVG-COMMON-1"]},
            {"userId": "u2", "candidateIds": ["ASH-COMMON-1", "MWB-COMMON-1"]},
        ]
    )
    picks = [s["arcoriId"] for s in out["selections"]]
    assert picks[0] == "ASH-COMMON-1"
    assert picks[1] == "MWB-COMMON-1"
    assert len(set(picks)) == 2


def test_select_gatherer_from_region_excludes_seated(select_root: Path):
    import random

    from modules.catalog.catalog_select import select_gatherer_for_region

    g = select_gatherer_for_region(
        "ASH",
        exclude_ids=["ASH-COMMON-1"],
        rng=random.Random(0),
    )
    # Only ASH-COMMON-1 in fixture for ASH → empty after exclude
    assert g is None

    g2 = select_gatherer_for_region("ASH", exclude_ids=[], rng=random.Random(0))
    assert g2 is not None
    assert g2["gathererArcoriId"] == "ASH-COMMON-1"
    assert g2["source"] in {
        "gatherer_weighted",
        "gatherer_random",
    }


def test_select_arena_includes_gatherer(select_root: Path):
    import random

    _install_arenas(select_root)
    # Majority ASH — gatherer from ASH excluding the two seated ASH ids (same id twice)
    out = select_arena_for_arcori_ids(
        ["ASH-COMMON-1", "ASH-COMMON-1", "EVG-COMMON-1"],
        rng=random.Random(0),
    )
    assert out["regionCode"] == "ASH"
    # Only one ASH design in fixture and it is excluded → no gatherer
    assert "gathererArcoriId" not in out

    # Add a second ASH design so gatherer can pick it
    path = select_root / "series" / "001_test" / "Animals.json"
    doc = json.loads(path.read_text(encoding="utf-8"))
    doc["designs"].append(
        {
            "internalId": "ASH-COMMON-2",
            "design": "Ash Common Two",
            "selectionWeight": 3.0,
            "worldState": "Active",
            "location": {"regionCode": "ASH"},
        }
    )
    path.write_text(json.dumps(doc), encoding="utf-8")
    loader.clear_caches()

    out2 = select_arena_for_arcori_ids(
        ["ASH-COMMON-1", "ASH-COMMON-1", "EVG-COMMON-1"],
        rng=random.Random(0),
    )
    assert out2["gathererArcoriId"] == "ASH-COMMON-2"
    assert out2["gathererArcoriId"] not in {"ASH-COMMON-1", "EVG-COMMON-1"}


def test_preferred_id_honored_when_in_candidates(
    select_root: Path, monkeypatch: pytest.MonkeyPatch
):
    monkeypatch.setattr(
        "modules.catalog.catalog_select._resolve_design",
        loader.find_design_by_internal_id,
    )
    out = select_for_seats(
        [
            {
                "userId": "u1",
                "candidateIds": ["ASH-COMMON-1", "EVG-COMMON-1", "MWB-COMMON-1"],
                "preferredId": "MWB-COMMON-1",
            }
        ]
    )
    pick = out["selections"][0]
    assert pick["arcoriId"] == "MWB-COMMON-1"
    assert pick["source"] == "preferred"
    assert pick["reason"] == "preferred_id"


def test_preferred_id_rejected_when_not_in_candidates(
    select_root: Path, monkeypatch: pytest.MonkeyPatch
):
    monkeypatch.setattr(
        "modules.catalog.catalog_select._resolve_design",
        loader.find_design_by_internal_id,
    )

    def fake_weighted(ids, weights):
        return ids[0]

    monkeypatch.setattr(
        "modules.catalog.catalog_select._weighted_pick",
        fake_weighted,
    )
    out = select_for_seats(
        [
            {
                "userId": "u1",
                "candidateIds": ["ASH-COMMON-1", "EVG-COMMON-1"],
                "preferredId": "MWB-COMMON-1",
            }
        ]
    )
    pick = out["selections"][0]
    assert pick["arcoriId"] == "ASH-COMMON-1"
    assert pick["source"] != "preferred"


def test_preferred_id_rejected_when_already_taken(
    select_root: Path, monkeypatch: pytest.MonkeyPatch
):
    monkeypatch.setattr(
        "modules.catalog.catalog_select._resolve_design",
        loader.find_design_by_internal_id,
    )

    def fake_weighted(ids, weights):
        return ids[0]

    monkeypatch.setattr(
        "modules.catalog.catalog_select._weighted_pick",
        fake_weighted,
    )
    out = select_for_seats(
        [
            {
                "userId": "u1",
                "candidateIds": ["ASH-COMMON-1"],
                "preferredId": "ASH-COMMON-1",
            },
            {
                "userId": "u2",
                "candidateIds": ["ASH-COMMON-1", "EVG-COMMON-1"],
                "preferredId": "ASH-COMMON-1",
            },
        ]
    )
    picks = out["selections"]
    assert picks[0]["arcoriId"] == "ASH-COMMON-1"
    assert picks[0]["source"] == "preferred"
    assert picks[1]["arcoriId"] == "EVG-COMMON-1"
    assert picks[1]["source"] != "preferred"
