"""Bake claim backgrounds into Kin Lottie JSON."""

from __future__ import annotations

import base64
import json
import unittest
from pathlib import Path
from unittest.mock import patch

from modules.avari.kin_lottie_background import (
    bake_claim_background_into_lottie,
)


class TestKinLottieBackgroundBake(unittest.TestCase):
    def test_solid_injects_background_layer(self) -> None:
        lottie = {
            "v": "5.7.4",
            "w": 64,
            "h": 64,
            "fr": 30,
            "ip": 0,
            "op": 30,
            "assets": [],
            "layers": [
                {
                    "ddd": 0,
                    "ind": 1,
                    "ty": 2,
                    "nm": "head",
                    "refId": "asset_head",
                    "ks": {
                        "o": {"a": 0, "k": 100},
                        "r": {"a": 0, "k": 0},
                        "p": {"a": 0, "k": [32, 32, 0]},
                        "a": {"a": 0, "k": [32, 32, 0]},
                        "s": {"a": 0, "k": [100, 100, 100]},
                    },
                }
            ],
        }
        out = bake_claim_background_into_lottie(
            lottie,
            {"theme": "SOLID", "colorHex": "#112233"},
        )
        names = [L.get("nm") for L in out["layers"]]
        self.assertEqual(names[-1], "background")
        self.assertIn("head", names)
        asset = next(a for a in out["assets"] if a["id"] == "asset_background")
        self.assertTrue(str(asset["p"]).startswith("data:image/webp;base64,"))
        raw = base64.b64decode(asset["p"].split(",", 1)[1])
        self.assertGreater(len(raw), 32)

    def test_entelair_metallic_promoted(self) -> None:
        tiny = (
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8"
            "z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
        )
        lottie = {
            "w": 32,
            "h": 32,
            "assets": [
                {
                    "id": "asset_background",
                    "w": 32,
                    "h": 32,
                    "u": "",
                    "p": f"data:image/png;base64,{tiny}",
                    "e": 1,
                }
            ],
            "layers": [
                {
                    "ind": 1,
                    "ty": 2,
                    "nm": "background",
                    "refId": "asset_background",
                    "ks": {
                        "o": {"a": 0, "k": 100},
                        "r": {"a": 0, "k": 0},
                        "p": {"a": 0, "k": [16, 16, 0]},
                        "a": {"a": 0, "k": [16, 16, 0]},
                        "s": {"a": 0, "k": [100, 100, 100]},
                    },
                }
            ],
        }
        out = bake_claim_background_into_lottie(
            lottie,
            {"theme": "SOLID", "colorHex": "#ABCDEF"},
        )
        names = [L.get("nm") for L in out["layers"]]
        self.assertIn("metallic_plate", names)
        self.assertEqual(names[-1], "background")
        bg = next(L for L in out["layers"] if L.get("nm") == "background")
        self.assertEqual(bg["ks"]["p"]["k"], [0, 0, 0])
        self.assertEqual(bg["ks"]["a"]["k"], [0, 0, 0])
        ids = {a["id"] for a in out["assets"]}
        self.assertIn("asset_metallic_plate", ids)
        self.assertIn("asset_background", ids)

    def test_nonsquare_expanded_to_square(self) -> None:
        lottie = {
            "w": 100,
            "h": 200,
            "assets": [],
            "layers": [
                {
                    "nm": "head",
                    "ty": 2,
                    "ind": 1,
                    "ks": {
                        "o": {"a": 0, "k": 100},
                        "r": {"a": 0, "k": 0},
                        "p": {"a": 0, "k": [50, 100, 0]},
                        "a": {"a": 0, "k": [0, 0, 0]},
                        "s": {"a": 0, "k": [100, 100, 100]},
                    },
                }
            ],
        }
        out = bake_claim_background_into_lottie(
            lottie,
            {"theme": "SOLID", "colorHex": "#112233"},
        )
        self.assertEqual(out["w"], 200)
        self.assertEqual(out["h"], 200)
        head = next(L for L in out["layers"] if L.get("nm") == "head")
        self.assertEqual(head["ks"]["p"]["k"][0], 100.0)  # 50 + pad_x 50
        self.assertEqual(head["ks"]["p"]["k"][1], 100.0)  # 100 + pad_y 0
        bg_asset = next(a for a in out["assets"] if a["id"] == "asset_background")
        self.assertEqual(bg_asset["w"], 200)
        self.assertEqual(bg_asset["h"], 200)
        bg = next(L for L in out["layers"] if L.get("nm") == "background")
        self.assertEqual(bg["ks"]["s"]["k"][:2], [100.0, 100.0])

    def test_tall_canvas_caps_bg_raster_with_layer_scale(self) -> None:
        """Entelair square-pad tall comps must not bake a full-res BG (OOM / gray)."""
        lottie = {
            "w": 1400,
            "h": 1400,
            "assets": [],
            "layers": [{"nm": "head", "ty": 2, "ind": 1}],
        }
        out = bake_claim_background_into_lottie(
            lottie,
            {"theme": "SOLID", "colorHex": "#112233"},
        )
        self.assertEqual(out["w"], 1400)
        self.assertEqual(out["h"], 1400)
        bg_asset = next(a for a in out["assets"] if a["id"] == "asset_background")
        self.assertEqual(bg_asset["w"], 384)
        self.assertEqual(bg_asset["h"], 384)
        bg = next(L for L in out["layers"] if L.get("nm") == "background")
        scale = bg["ks"]["s"]["k"][0]
        self.assertAlmostEqual(float(scale), 100.0 * 1400 / 384, places=4)

    def test_image_url_reads_disk(self) -> None:
        from PIL import Image

        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / "KIN_BG_ABSTRACT_TEST_001.webp"
            Image.new("RGB", (16, 16), (200, 40, 40)).save(path, format="WEBP")
            with patch(
                "modules.avari.kin_backgrounds.backgrounds_dir",
                return_value=root,
            ):
                lottie = {"w": 32, "h": 32, "assets": [], "layers": []}
                out = bake_claim_background_into_lottie(
                    lottie,
                    {
                        "theme": "ABSTRACT",
                        "fileName": path.name,
                        "imageUrl": (
                            f"/catalog-media/kin/ser001/00backgrounds/{path.name}"
                        ),
                    },
                )
                self.assertEqual(out["layers"][-1]["nm"], "background")

    def test_rebake_guardian_keeps_single_background(self) -> None:
        lottie = {
            "w": 32,
            "h": 32,
            "assets": [],
            "layers": [{"nm": "head", "ty": 2, "ind": 1}],
        }
        bg = {"theme": "SOLID", "colorHex": "#112233"}
        once = bake_claim_background_into_lottie(lottie, bg)
        twice = bake_claim_background_into_lottie(once, bg)
        names = [L.get("nm") for L in twice["layers"]]
        self.assertEqual(names.count("background"), 1)
        self.assertNotIn("metallic_plate", names)
        self.assertTrue(twice["layers"][-1].get("arcoriClaimBg"))


if __name__ == "__main__":
    unittest.main()
