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
                    internal_id="KIN-A-SER001-0001",
                    chosen_name="Alpha",
                    region_code="EVG",
                    color="#C6A15B",
                    subtheme="Guardians",
                    player_id="u1",
                )
                d2 = build_kin_catalog_design(
                    internal_id="KIN-B-SER001-0002",
                    chosen_name="Beta",
                    region_code="ASH",
                    color="#A8B0B8",
                    subtheme="Walkies",
                    player_id="u2",
                )
                store.write_design_file("KIN-A-SER001-0001", d1)
                store.write_design_file("KIN-B-SER001-0002", d2)

                listed = store.list_design_files()
                ids = {d["internalId"] for d in listed}
                self.assertEqual(ids, {"KIN-A-SER001-0001", "KIN-B-SER001-0002"})

                # Concurrent-safe shape: two separate files, not one shared category.
                root = Path(tmp) / "kin" / "designs"
                self.assertTrue((root / "KIN-A-SER001-0001.json").is_file())
                self.assertTrue((root / "KIN-B-SER001-0002.json").is_file())

                loaded = store.read_design_file("KIN-A-SER001-0001")
                self.assertEqual(loaded["design"], "Alpha")

    def test_index_includes_kin_theme_from_files(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(store, "upload_root", return_value=tmp):
                design = build_kin_catalog_design(
                    internal_id="KIN-VELORA-SER005-GEN001-0001",
                    chosen_name="VeloraKin",
                    region_code="MWB",
                    color="#4E7A78",
                    subtheme="Entelairs",
                    player_id="u3",
                )
                store.write_design_file("KIN-VELORA-SER005-GEN001-0001", design)
                with patch(
                    "modules.catalog.catalog_service._live_player_kin_id_keys",
                    return_value={
                        "KIN-VELORA-SER005-GEN001-0001",
                        "KIN-VELORA-SER005-0001",
                    },
                ):
                    result = get_index(theme="KIN", circulating=True)
                ids = {item["internalId"] for item in result["items"]}
                self.assertIn("KIN-VELORA-SER005-GEN001-0001", ids)
                kin_item = next(
                    i
                    for i in result["items"]
                    if i["internalId"] == "KIN-VELORA-SER005-GEN001-0001"
                )
                self.assertEqual(kin_item["themeCode"], "KIN")
                self.assertTrue(str(kin_item.get("lottieUrl") or "").endswith(".json"))

    def test_genesis_index_excludes_legacy_genesis_stamped_kin(self) -> None:
        """Old admin Kin files said series=Genesis Series — must not appear under Genesis."""
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(store, "upload_root", return_value=tmp):
                design = build_kin_catalog_design(
                    internal_id="KIN-ADMINLEGACY-SER001-GEN001-0501",
                    chosen_name="LegacyStamp",
                    region_code="ASH",
                    color="#C6A15B",
                    subtheme="Guardians",
                    player_id="u4",
                )
                design["series"] = "Genesis Series"
                store.write_design_file(
                    "KIN-ADMINLEGACY-SER001-GEN001-0501", design
                )
                live = {
                    "KIN-ADMINLEGACY-SER001-GEN001-0501",
                    "KIN-ADMINLEGACY-SER001-0501",
                }
                with patch(
                    "modules.catalog.catalog_service._live_player_kin_id_keys",
                    return_value=live,
                ):
                    genesis = get_index(series="Genesis", circulating=True)
                themes = {
                    (item.get("theme") or "").lower()
                    for item in genesis["items"]
                }
                self.assertNotIn("kin", themes)
                kin_ids = {
                    item["internalId"]
                    for item in genesis["items"]
                    if str(item.get("internalId") or "").upper().startswith("KIN-")
                }
                self.assertEqual(kin_ids, set())

                with patch(
                    "modules.catalog.catalog_service._live_player_kin_id_keys",
                    return_value=live,
                ):
                    kin_browse = get_index(series="Kin", circulating=True)
                kin_browse_ids = {
                    item["internalId"] for item in kin_browse["items"]
                }
                self.assertIn(
                    "KIN-ADMINLEGACY-SER001-GEN001-0501", kin_browse_ids
                )

                # Orphan file (not in player_kin) must not appear.
                orphan = build_kin_catalog_design(
                    internal_id="KIN-ORPHAN-SER005-GEN001-9999",
                    chosen_name="Orphan",
                    region_code="EVG",
                    color="#A8B0B8",
                    subtheme="Walkies",
                    player_id="u5",
                )
                store.write_design_file("KIN-ORPHAN-SER005-GEN001-9999", orphan)
                with patch(
                    "modules.catalog.catalog_service._live_player_kin_id_keys",
                    return_value=live,
                ):
                    kin_browse2 = get_index(series="Kin", circulating=True)
                self.assertNotIn(
                    "KIN-ORPHAN-SER005-GEN001-9999",
                    {item["internalId"] for item in kin_browse2["items"]},
                )


if __name__ == "__main__":
    unittest.main()
