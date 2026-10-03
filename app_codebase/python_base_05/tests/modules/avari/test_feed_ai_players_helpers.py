"""Tests for AI feed helpers (no DB feed)."""

from __future__ import annotations

import json
import random
import unittest
from pathlib import Path
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[5]
FEED = REPO / "automation" / "backend" / "feed_ai_players.py"
SEED = REPO / "automation" / "backend" / "data" / "ai_players_500.json"


class TestAiPlayersSeedJson(unittest.TestCase):
    def test_seed_has_500_unique_usernames_and_kin_names(self) -> None:
        data = json.loads(SEED.read_text(encoding="utf-8"))
        self.assertEqual(data.get("emailDomain"), "arcoriaiplayer.app")
        self.assertEqual(data.get("marker"), "ai_seed:v1")
        players = data["players"]
        self.assertEqual(len(players), 500)
        users = [p["username"].lower() for p in players]
        kins = [p["kinName"].lower() for p in players]
        self.assertEqual(len(set(users)), 500)
        self.assertEqual(len(set(kins)), 500)
        for p in players:
            self.assertTrue(p["username"])
            self.assertTrue(p["kinName"])


class TestAiEmailDomainConstant(unittest.TestCase):
    def test_players_service_domain(self) -> None:
        # Avoid importing sqlalchemy-heavy module; assert constant in source.
        text = (
            REPO
            / "app_codebase"
            / "python_base_05"
            / "bin"
            / "modules"
            / "players"
            / "players_service.py"
        ).read_text(encoding="utf-8")
        self.assertIn('AI_EMAIL_DOMAIN = "@arcoriaiplayer.app"', text)
        self.assertIn('AI_SEED_MARKER = "ai_seed:v1"', text)


class TestBuildRandomKinClaimBody(unittest.TestCase):
    def test_constraints(self) -> None:
        import importlib.util
        import sys

        bin_dir = str(REPO / "app_codebase" / "python_base_05" / "bin")
        if bin_dir not in sys.path:
            sys.path.insert(0, bin_dir)

        spec = importlib.util.spec_from_file_location("feed_ai_players", FEED)
        assert spec and spec.loader
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)

        from modules.avari.kin_genesis import ALLOWED_ARCORI_COLORS, EXCLUDED_KIN_REGION

        fake_bgs = {
            "backgrounds": [
                {
                    "id": "bg1",
                    "fileName": "KIN_BG_ABSTRACT_REALISTIC_001.webp",
                    "imageUrl": "/catalog-media/kin/ser001/00backgrounds/KIN_BG_ABSTRACT_REALISTIC_001.webp",
                }
            ],
            "themes": [],
            "stylesByTheme": {},
        }
        with patch(
            "modules.avari.kin_backgrounds.list_kin_backgrounds",
            return_value=fake_bgs,
        ):
            body = mod.build_random_kin_claim_body(
                kin_name="Fenn",
                rng=random.Random(1),
            )
        self.assertEqual(body["chosenName"], "Fenn")
        self.assertIsInstance(body["applied"], list)
        self.assertIn(body["color"], ALLOWED_ARCORI_COLORS)
        self.assertNotEqual(body["regionCode"], EXCLUDED_KIN_REGION)
        self.assertTrue(body["kinSerial"])
        self.assertTrue(body["typeSerial"])
        self.assertEqual(body.get("background"), fake_bgs["backgrounds"][0])
        self.assertNotIn("lottie", body)
        for row in body["applied"]:
            self.assertIsInstance(row, dict)
            self.assertTrue(row.get("partSerial"))
            self.assertTrue(row.get("customSerial"))
            self.assertIn("value", row)


class TestRandomAppliedCustoms(unittest.TestCase):
    def _load_feed(self):
        import importlib.util
        import sys

        bin_dir = str(REPO / "app_codebase" / "python_base_05" / "bin")
        if bin_dir not in sys.path:
            sys.path.insert(0, bin_dir)

        spec = importlib.util.spec_from_file_location("feed_ai_players", FEED)
        assert spec and spec.loader
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        return mod

    def test_numeric_intensity_stays_in_band(self) -> None:
        mod = self._load_feed()
        params = {"min": -180, "max": 180, "step": 1, "default": 0}
        rng = random.Random(7)
        for _ in range(40):
            value = mod._random_numeric_at_intensity(params, rng)
            mag = abs(float(value))
            self.assertGreaterEqual(mag, 0.3 * 180 - 1)
            self.assertLessEqual(mag, 0.8 * 180 + 1)
            self.assertGreaterEqual(float(value), -180)
            self.assertLessEqual(float(value), 180)

    def test_build_random_applied_uses_part_pool_and_tints(self) -> None:
        mod = self._load_feed()
        customs = mod._load_customs_by_serial()
        kin_row = {
            "serial": "KIN-TEST",
            "parts": [
                {
                    "serial": "KPART-HEAD",
                    "allowedCustomSerials": ["CUS-0001", "CUS-0008", "CUS-0006"],
                    "embedPoolSerials": ["KEMB-0001", "KEMB-0002"],
                },
                {
                    "serial": "KPART-EYE",
                    "allowedCustomSerials": ["CUS-0003", "CUS-0005"],
                    "embedPoolSerials": [],
                },
            ],
        }
        with patch.object(mod, "_P_APPLY_PART_CUSTOM", 1.0), patch.object(
            mod, "_P_INCLUDE_EMBED", 1.0
        ), patch.object(mod, "_P_EMBED_HUE", 1.0), patch.object(
            mod, "_P_EMBED_LIGHT", 1.0
        ):
            applied = mod._build_random_applied(
                kin_row, customs, random.Random(3)
            )

        by_key = {
            (r["partSerial"], r["customSerial"]): r["value"] for r in applied
        }
        self.assertIn(("KPART-HEAD", "CUS-0001"), by_key)
        self.assertIn(("KPART-HEAD", "CUS-0008"), by_key)
        self.assertIn(("KPART-EYE", "CUS-0003"), by_key)
        self.assertIn(("KPART-EYE", "CUS-0005"), by_key)
        embed_val = by_key[("KPART-HEAD", "CUS-0006")]
        self.assertIsInstance(embed_val, dict)
        self.assertEqual(set(embed_val.keys()), {"KEMB-0001", "KEMB-0002"})
        for tint in embed_val.values():
            self.assertIn("hue", tint)
            self.assertIn("lightDark", tint)
            self.assertGreaterEqual(abs(float(tint["hue"])), 0.3 * 180 - 1)
            self.assertLessEqual(abs(float(tint["hue"])), 0.8 * 180 + 1)
            self.assertGreaterEqual(abs(float(tint["lightDark"])), 0.3 - 0.02)
            self.assertLessEqual(abs(float(tint["lightDark"])), 0.8 + 0.02)

    def test_walkie_catalog_parity_with_feed_random_applied(self) -> None:
        """Walkies must sit in the feed pool with hue/lightDark + addition embeds."""
        mod = self._load_feed()
        _types, kins = mod._load_kin_catalog()
        customs = mod._load_customs_by_serial()
        walkies = [
            k
            for k in kins
            if isinstance(k, dict)
            and "/walkies/" in str(k.get("lottieUrl") or "")
        ]
        self.assertEqual(len(walkies), 10)
        for kin in walkies:
            url = str(kin.get("lottieUrl") or "")
            path = mod._catalog_lottie_disk_path(url)
            self.assertTrue(path.is_file(), msg=f"missing {kin.get('serial')} {url}")

            customs_allowed: set[str] = set()
            embed_pool: list[str] = []
            for part in kin.get("parts") or []:
                if not isinstance(part, dict):
                    continue
                customs_allowed.update(
                    str(s) for s in (part.get("allowedCustomSerials") or [])
                )
                embed_pool.extend(
                    str(s) for s in (part.get("embedPoolSerials") or []) if str(s)
                )
            self.assertIn("CUS-0003", customs_allowed)
            self.assertIn("CUS-0008", customs_allowed)
            self.assertIn("CUS-0006", customs_allowed)
            self.assertGreaterEqual(len(embed_pool), 4, msg=kin.get("serial"))

            with patch.object(mod, "_P_APPLY_PART_CUSTOM", 1.0), patch.object(
                mod, "_P_INCLUDE_EMBED", 1.0
            ), patch.object(mod, "_P_EMBED_HUE", 1.0), patch.object(
                mod, "_P_EMBED_LIGHT", 1.0
            ):
                applied = mod._build_random_applied(
                    kin, customs, random.Random(11)
                )
            by_c = {r["customSerial"]: r for r in applied}
            self.assertIn("CUS-0003", by_c)
            self.assertIn("CUS-0008", by_c)
            self.assertIn("CUS-0006", by_c)
            emb = by_c["CUS-0006"]["value"]
            self.assertIsInstance(emb, dict)
            self.assertEqual(set(emb.keys()), set(embed_pool))
            for tint in emb.values():
                self.assertIn("hue", tint)
                self.assertIn("lightDark", tint)


class TestCatalogLottieDiskPath(unittest.TestCase):
    def test_maps_catalog_media_url(self) -> None:
        import importlib.util
        import sys

        bin_dir = str(REPO / "app_codebase" / "python_base_05" / "bin")
        if bin_dir not in sys.path:
            sys.path.insert(0, bin_dir)

        spec = importlib.util.spec_from_file_location("feed_ai_players", FEED)
        assert spec and spec.loader
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)

        path = mod._catalog_lottie_disk_path(
            "/catalog-media/kin/ser001/entelairs/KIN-ALC-SER001-0005.json"
        )
        self.assertTrue(path.is_file())
        self.assertEqual(path.name, "KIN-ALC-SER001-0005.json")


if __name__ == "__main__":
    unittest.main()
