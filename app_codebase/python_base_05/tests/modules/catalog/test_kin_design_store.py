"""Per-Kin design files + catalog index merge."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from modules.avari.kin_genesis import build_kin_catalog_design
from modules.catalog import kin_design_store as store
from modules.catalog.catalog_service import get_index


class KinDesignStoreTests(unittest.TestCase):
    def test_write_and_list_independent_files(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(store, "upload_root", return_value=tmp):
                d1 = build_kin_catalog_design(
                    internal_id="KIN-A-GEN001-0001",
                    chosen_name="Alpha",
                    region_code="EVG",
                    color="#C6A15B",
                    subtheme="Guardians",
                    player_id="u1",
                )
                d2 = build_kin_catalog_design(
                    internal_id="KIN-B-GEN001-0002",
                    chosen_name="Beta",
                    region_code="ASH",
                    color="#A8B0B8",
                    subtheme="Walkies",
                    player_id="u2",
                )
                store.write_design_file("KIN-A-GEN001-0001", d1)
                store.write_design_file("KIN-B-GEN001-0002", d2)

                listed = store.list_design_files()
                ids = {d["internalId"] for d in listed}
                self.assertEqual(ids, {"KIN-A-GEN001-0001", "KIN-B-GEN001-0002"})

                # Concurrent-safe shape: two separate files, not one shared category.
                root = Path(tmp) / "kin" / "designs"
                self.assertTrue((root / "KIN-A-GEN001-0001.json").is_file())
                self.assertTrue((root / "KIN-B-GEN001-0002.json").is_file())

                loaded = store.read_design_file("KIN-A-GEN001-0001")
                self.assertEqual(loaded["design"], "Alpha")

    def test_index_includes_kin_theme_from_files(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(store, "upload_root", return_value=tmp):
                design = build_kin_catalog_design(
                    internal_id="KIN-VELORA-GEN001-0001",
                    chosen_name="VeloraKin",
                    region_code="MWB",
                    color="#4E7A78",
                    subtheme="Entelairs",
                    player_id="u3",
                )
                store.write_design_file("KIN-VELORA-GEN001-0001", design)
                result = get_index(theme="KIN", circulating=True)
                ids = {item["internalId"] for item in result["items"]}
                self.assertIn("KIN-VELORA-GEN001-0001", ids)
                kin_item = next(
                    i for i in result["items"] if i["internalId"] == "KIN-VELORA-GEN001-0001"
                )
                self.assertEqual(kin_item["themeCode"], "KIN")
                self.assertTrue(str(kin_item.get("lottieUrl") or "").endswith(".json"))


if __name__ == "__main__":
    unittest.main()
