"""Kin Genesis design builder — key parity with regular Arcori."""

from __future__ import annotations

import unittest

from modules.avari.kin_genesis import (
    ALLOWED_ARCORI_COLORS,
    CURRENT_KIN_SERIES,
    REGULAR_ARCORI_DESIGN_KEYS,
    assert_design_key_parity,
    build_kin_catalog_design,
    mint_internal_id,
    normalize_color,
)
from modules.catalog import catalog_loader as loader
from modules.catalog.current_series import CURRENT_SERIES, current_id_token


class KinGenesisTests(unittest.TestCase):
    def test_normalize_color(self) -> None:
        self.assertEqual(normalize_color("#c6a15b"), "#C6A15B")
        self.assertEqual(normalize_color("C6A15B"), "#C6A15B")
        self.assertIsNone(normalize_color("#FFFFFF"))
        self.assertIsNone(normalize_color("nope"))

    def test_allowed_palette_size(self) -> None:
        self.assertEqual(len(ALLOWED_ARCORI_COLORS), 10)

    def test_current_series_is_genesis_gen001(self) -> None:
        """Launch matches static catalog Arcori (…-GEN001-…)."""
        self.assertEqual(CURRENT_SERIES["idToken"], "GEN001")
        self.assertEqual(CURRENT_SERIES["seriesKey"], "Genesis")
        self.assertEqual(CURRENT_SERIES["seriesDisplay"], "Genesis Series")
        self.assertEqual(CURRENT_SERIES["generation"]["number"], 1)
        self.assertEqual(CURRENT_SERIES["generation"]["roman"], "I")
        self.assertIs(CURRENT_KIN_SERIES, CURRENT_SERIES)

    def test_mint_internal_id_embeds_current_series_token(self) -> None:
        iid = mint_internal_id(username="admin", seq=1)
        self.assertIn(f"-{current_id_token()}-", iid)
        self.assertTrue(iid.startswith("KIN-"))
        self.assertTrue(iid.endswith("-0001"))
        # Same token position as Tiger ANM-TIG-GEN001-0001
        self.assertRegex(iid, r"^KIN-[A-Z0-9]+-GEN001-\d{4}$")

    def test_design_key_parity_vs_tiger(self) -> None:
        animals = loader.load_json_file(
            loader.get_data_root() / "series" / "genesis" / "animals.json"
        )
        tiger = animals["designs"][0]
        self.assertEqual(frozenset(tiger.keys()), REGULAR_ARCORI_DESIGN_KEYS)
        self.assertIn("-GEN001-", tiger["internalId"])

        design = build_kin_catalog_design(
            internal_id="KIN-TEST202601010000-GEN001-0001",
            chosen_name="Test Kin",
            region_code="EVG",
            color="#C6A15B",
            subtheme="Guardians",
            player_id="a0000000-0000-4000-8000-000000000001",
        )
        assert_design_key_parity(design)
        self.assertEqual(design["themeCode"], "KIN")
        self.assertEqual(design["theme"], "Kin")
        self.assertEqual(design["series"], CURRENT_SERIES["seriesDisplay"])
        self.assertEqual(design["generation"]["roman"], "I")
        self.assertEqual(design["generation"]["number"], 1)
        self.assertEqual(design["generation"]["creator"]["type"], "player")
        self.assertEqual(design["location"]["regionCode"], "EVG")
        self.assertEqual(design["color"], "#C6A15B")
        self.assertIsNone(design["selectionWeight"])
        self.assertIn("AMB", design["affinity"])  # EVG Living Pact
        self.assertEqual(
            design["legacy"]["preservationRequirement"],
            CURRENT_SERIES["legacy"]["preservationRequirement"],
        )

    def test_sample_kin_meta_key_parity(self) -> None:
        kin_meta = loader.load_meta("kin")
        design = kin_meta["designs"][0]
        self.assertEqual(frozenset(design.keys()), REGULAR_ARCORI_DESIGN_KEYS)
        self.assertIn("color", design)
        self.assertIn("-GEN001-", design["internalId"])


if __name__ == "__main__":
    unittest.main()
