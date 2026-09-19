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
    pick_echo_color,
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

    def test_pick_echo_color_from_approved_palette(self) -> None:
        for _ in range(20):
            color = pick_echo_color("#C6A15B")
            self.assertIn(color, ALLOWED_ARCORI_COLORS)
            self.assertNotEqual(color, "#C6A15B")

    def test_pick_echo_color_without_previous(self) -> None:
        color = pick_echo_color(None)
        self.assertIn(color, ALLOWED_ARCORI_COLORS)

    def test_current_series_is_genesis_ser001(self) -> None:
        """Launch matches static catalog Arcori (…-SER001-…)."""
        self.assertEqual(CURRENT_SERIES["idToken"], "SER001")
        self.assertEqual(CURRENT_SERIES["seriesKey"], "Genesis")
        self.assertEqual(CURRENT_SERIES["seriesDisplay"], "Genesis Series")
        self.assertEqual(CURRENT_SERIES["mediaFolder"], "001_genesis")
        self.assertEqual(CURRENT_SERIES["generation"]["number"], 1)
        self.assertEqual(CURRENT_SERIES["generation"]["roman"], "I")
        self.assertIs(CURRENT_KIN_SERIES, CURRENT_SERIES)

    def test_mint_internal_id_embeds_current_series_token(self) -> None:
        iid = mint_internal_id(username="admin", seq=1)
        self.assertIn(f"-{current_id_token()}-", iid)
        self.assertTrue(iid.startswith("KIN-"))
        self.assertTrue(iid.endswith("-0001"))
        # Same token position as Tiger ANM-TIG-SER001-0001
        self.assertRegex(iid, r"^KIN-[A-Z0-9]+-SER001-GEN001-\d{4}$")

    def test_design_key_parity_vs_tiger(self) -> None:
        animals = loader.load_json_file(
            loader.get_data_root() / "series" / "genesis" / "animals.json"
        )
        tiger = animals["designs"][0]
        self.assertEqual(frozenset(tiger.keys()), REGULAR_ARCORI_DESIGN_KEYS)
        self.assertIn("-SER001-", tiger["internalId"])

        design = build_kin_catalog_design(
            internal_id="KIN-TEST202601010000-SER001-0001",
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
        self.assertEqual(design["selectionWeight"], 3.0)
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
        self.assertIn("-SER001-", design["internalId"])


if __name__ == "__main__":
    unittest.main()
