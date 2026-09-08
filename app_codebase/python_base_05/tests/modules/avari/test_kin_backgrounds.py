"""Kin background filename scan / parse."""

from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path

from modules.avari.kin_backgrounds import (
    list_kin_backgrounds,
    parse_background_filename,
)


class KinBackgroundsTests(unittest.TestCase):
    def test_parse_abstract_low_poly(self) -> None:
        row = parse_background_filename("KIN_BG_ABSTRACT_LOW_POLY_009.webp")
        assert row is not None
        self.assertEqual(row["theme"], "ABSTRACT")
        self.assertEqual(row["style"], "LOW_POLY")
        self.assertEqual(row["seq"], "009")
        self.assertEqual(row["id"], "KIN_BG_ABSTRACT_LOW_POLY_009")
        self.assertTrue(row["imageUrl"].endswith("/KIN_BG_ABSTRACT_LOW_POLY_009.webp"))

    def test_parse_future_theme_without_code_change(self) -> None:
        row = parse_background_filename("KIN_BG_FOREST_PIXEL_ART_021.webp")
        assert row is not None
        self.assertEqual(row["theme"], "FOREST")
        self.assertEqual(row["style"], "PIXEL_ART")

    def test_reject_bad_name(self) -> None:
        self.assertIsNone(parse_background_filename("not-a-bg.webp"))
        self.assertIsNone(parse_background_filename("KIN_BG_ONLY.webp"))

    def test_list_scans_directory(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            bg = root / "gen001" / "00backgrounds"
            bg.mkdir(parents=True)
            (bg / "KIN_BG_ABSTRACT_NEON_006.webp").write_bytes(b"x")
            (bg / "KIN_BG_SCENERY_RETRO_020.webp").write_bytes(b"x")
            (bg / "readme.txt").write_text("ignore")
            (bg / "KIN_BG_BAD.webp").write_bytes(b"x")
            prev = os.environ.get("CATALOG_KIN_MEDIA_ROOT")
            os.environ["CATALOG_KIN_MEDIA_ROOT"] = str(root)
            try:
                data = list_kin_backgrounds()
            finally:
                if prev is None:
                    os.environ.pop("CATALOG_KIN_MEDIA_ROOT", None)
                else:
                    os.environ["CATALOG_KIN_MEDIA_ROOT"] = prev

            self.assertEqual(len(data["backgrounds"]), 2)
            self.assertEqual(data["themes"], ["ABSTRACT", "SCENERY"])
            self.assertEqual(data["stylesByTheme"]["ABSTRACT"], ["NEON"])
            self.assertEqual(data["stylesByTheme"]["SCENERY"], ["RETRO"])


if __name__ == "__main__":
    unittest.main()
