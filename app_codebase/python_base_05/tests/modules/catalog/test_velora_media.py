"""Velora media URL helpers + regions meta enrichment."""

from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path

from modules.catalog.velora_media import (
    arena_image_url,
    clear_caches,
    enrich_regions_meta,
    list_region_locations,
    region_image_url,
)


class VeloraMediaTests(unittest.TestCase):
    def tearDown(self) -> None:
        clear_caches()

    def test_arena_url_honors_image_file(self) -> None:
        self.assertEqual(
            arena_image_url(
                slug="ashdrift-hill",
                arena_id="ARN-ASH-HIL001-0001",
                image_file="ARN-ASH-HIL001-0001.webp",
            ),
            "/catalog-media/velora/arenas/ashdrift-hill/ARN-ASH-HIL001-0001.webp",
        )
        self.assertEqual(
            arena_image_url(slug="ashdrift-hill", arena_id="ARN-ASH-HIL001-0001"),
            "/catalog-media/velora/arenas/ashdrift-hill/ARN-ASH-HIL001-0001.webp",
        )

    def test_region_url(self) -> None:
        self.assertEqual(
            region_image_url(slug="everlight-grove"),
            "/catalog-media/velora/regions/everlight-grove/region.png",
        )

    def test_list_locations_mtime_cached(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            loc = root / "regions" / "ashdrift-hill" / "locations"
            loc.mkdir(parents=True)
            (loc / "hospital.png").write_bytes(b"x")
            (loc / "school.png").write_bytes(b"x")
            (loc / "notes.txt").write_text("ignore")
            prev = os.environ.get("CATALOG_VELORA_MEDIA_ROOT")
            os.environ["CATALOG_VELORA_MEDIA_ROOT"] = str(root)
            try:
                clear_caches()
                first = list_region_locations(slug="ashdrift-hill")
                self.assertEqual(len(first), 2)
                self.assertEqual(
                    first[0]["imageUrl"],
                    "/catalog-media/velora/regions/ashdrift-hill/locations/hospital.png",
                )
                # Same dir mtime → cache hit still returns two.
                second = list_region_locations(slug="ashdrift-hill")
                self.assertEqual(len(second), 2)
            finally:
                if prev is None:
                    os.environ.pop("CATALOG_VELORA_MEDIA_ROOT", None)
                else:
                    os.environ["CATALOG_VELORA_MEDIA_ROOT"] = prev
                clear_caches()

    def test_enrich_regions_meta(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            loc = root / "regions" / "ashdrift-hill" / "locations"
            loc.mkdir(parents=True)
            (loc / "walled-alley.png").write_bytes(b"x")
            maps = root / "maps"
            maps.mkdir(parents=True)
            (maps / "six-region-map.png").write_bytes(b"x")
            prev = os.environ.get("CATALOG_VELORA_MEDIA_ROOT")
            os.environ["CATALOG_VELORA_MEDIA_ROOT"] = str(root)
            try:
                clear_caches()
                doc = {
                    "regions": [
                        {
                            "regionCode": "ASH",
                            "slug": "ashdrift-hill",
                            "name": "Ashdrift Hill",
                            "arenas": [
                                {
                                    "arenaId": "ARN-ASH-HIL001-0001",
                                    "name": "Ashdrift Hill",
                                    "imageFile": "ARN-ASH-HIL001-0001.webp",
                                }
                            ],
                        }
                    ],
                    "arenaAssets": {"directory": "host-only"},
                }
                enriched = enrich_regions_meta(doc)
                region = enriched["regions"][0]
                self.assertEqual(
                    region["imageUrl"],
                    "/catalog-media/velora/regions/ashdrift-hill/region.png",
                )
                self.assertEqual(len(region["locations"]), 1)
                self.assertEqual(
                    region["arenas"][0]["imageUrl"],
                    "/catalog-media/velora/arenas/ashdrift-hill/ARN-ASH-HIL001-0001.webp",
                )
                self.assertEqual(len(enriched["maps"]), 1)
                self.assertIn("publicPrefix", enriched["arenaAssets"])
            finally:
                if prev is None:
                    os.environ.pop("CATALOG_VELORA_MEDIA_ROOT", None)
                else:
                    os.environ["CATALOG_VELORA_MEDIA_ROOT"] = prev
                clear_caches()


if __name__ == "__main__":
    unittest.main()
