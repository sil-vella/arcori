"""Avari Hands market catalog — same image hydrate as other designs."""

from __future__ import annotations

from pathlib import Path

from modules.catalog import catalog_loader as loader
from modules.catalog.catalog_authoring import iter_authored_designs
from modules.catalog.catalog_ids import art_basename, parse_design_id
from modules.catalog.catalog_select import _is_playable_match_arcori
from modules.catalog.catalog_service import design_summary, image_url_for
from modules.catalog.current_series import media_folder_for_series, series_is_active
from modules.market.market_skus import is_shop_hand, is_shop_slammer, shop_hand_price


def test_avari_hands_hydrate_like_other_catalog_items() -> None:
    loader.set_data_root_override(None)
    loader.clear_caches()
    doc = loader.find_theme_document_by_code("HND")
    assert doc is not None
    designs = doc["designs"]
    assert [d["design"] for d in designs] == [
        "Celestial Gold Hand",
        "Copper Arcane Hand",
        "Luminous Cybernetic Hand",
    ]
    assert series_is_active("Avari Hands") is False

    authored = [
        entry
        for entry in iter_authored_designs()
        if str(entry["design"].get("themeCode") or "").upper() == "HND"
    ]
    assert len(authored) == 3
    art_root = (
        Path(__file__).resolve().parents[5]
        / "assets"
        / "images"
        / "arcori"
        / "008_avari_hands"
        / "hands"
    )
    for entry in authored:
        design = entry["design"]
        assert entry["series_key"] == "Avari Hands"
        iid = design["internalId"]
        parsed = parse_design_id(iid)
        assert parsed is not None
        assert parsed.type_code == "ARC"
        assert parsed.theme_code == "HND"
        summary = design_summary(
            design, series_key=entry["series_key"], theme="Hands"
        )
        expected = image_url_for(
            series_key="Avari Hands",
            theme="Hands",
            internal_id=iid,
        )
        assert summary["imageUrl"] == expected
        assert expected == (
            f"/catalog-media/{media_folder_for_series('Avari Hands')}/hands/"
            f"{art_basename(iid)}.webp"
        )
        assert design["origin"] == "Shop"
        assert shop_hand_price(design) == 4
        assert is_shop_hand(design, design_id=iid) is True
        assert is_shop_slammer(design, design_id=iid) is False
        assert summary["faceMedia"] == "webp"
        assert (art_root / f"{art_basename(iid)}.webp").is_file()
        # Cosmetic hands stay out of match stock even if marked Active.
        playable = dict(design)
        playable["worldState"] = "Active"
        playable["series"] = "Genesis"
        assert _is_playable_match_arcori(playable) is False
