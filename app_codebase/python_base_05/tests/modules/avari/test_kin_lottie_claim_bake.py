"""Server-side Kin claim Lottie bake + optimize."""

from __future__ import annotations

import unittest
from pathlib import Path
from unittest.mock import patch

from modules.avari.kin_lottie_claim_bake import (
    build_claim_lottie,
    find_template_lottie_path,
)
from modules.avari.kin_lottie_optimize import optimize_lottie_payload


def _tiny_png_b64() -> str:
    # 1x1 PNG
    return (
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8"
        "z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    )


class TestKinLottieOptimize(unittest.TestCase):
    def test_optimize_uniform_scale_keeps_anchor_ratio(self) -> None:
        tiny = _tiny_png_b64()
        lottie = {
            "w": 2048,
            "h": 2048,
            "assets": [
                {
                    "id": "asset_head",
                    "w": 1000,
                    "h": 1000,
                    "u": "",
                    "p": f"data:image/png;base64,{tiny}",
                    "e": 1,
                }
            ],
            "layers": [
                {
                    "nm": "head",
                    "refId": "asset_head",
                    "ks": {
                        "p": {"a": 0, "k": [1024, 1024, 0]},
                        "a": {"a": 0, "k": [500, 500, 0]},
                        "s": {"a": 0, "k": [100, 100, 100]},
                    },
                }
            ],
        }
        out = optimize_lottie_payload(lottie, max_comp_edge=768)
        self.assertEqual(out["w"], 768)
        self.assertEqual(out["h"], 768)
        # Positions + anchors share the same scale factor (2048→768 = 0.375).
        self.assertAlmostEqual(out["layers"][0]["ks"]["p"]["k"][0], 384.0)
        self.assertAlmostEqual(out["layers"][0]["ks"]["a"]["k"][0], 187.5)
        # Layer scale % unchanged (visual size tracks uniform canvas shrink).
        self.assertEqual(out["layers"][0]["ks"]["s"]["k"][0], 100)

    def test_optimize_scales_layer_masks_with_assets(self) -> None:
        """Eye masks are in layer/asset space — must shrink with the PNG."""
        tiny = _tiny_png_b64()
        lottie = {
            "w": 2000,
            "h": 2000,
            "assets": [
                {
                    "id": "asset_left_eye",
                    "w": 200,
                    "h": 160,
                    "u": "",
                    "p": f"data:image/png;base64,{tiny}",
                    "e": 1,
                }
            ],
            "layers": [
                {
                    "nm": "left_eye",
                    "refId": "asset_left_eye",
                    "hasMask": True,
                    "masksProperties": [
                        {
                            "inv": False,
                            "mode": "a",
                            "pt": {
                                "a": 0,
                                "k": {
                                    "c": True,
                                    "v": [[100.0, 80.0], [150.0, 80.0]],
                                    "i": [[0.0, -10.0], [0.0, 10.0]],
                                    "o": [[0.0, 10.0], [0.0, -10.0]],
                                },
                            },
                            "o": {"a": 0, "k": 100},
                            "x": {"a": 0, "k": 0},
                        }
                    ],
                    "ks": {
                        "p": {"a": 0, "k": [1000.0, 1000.0, 0]},
                        "a": {"a": 0, "k": [100.0, 80.0, 0]},
                        "s": {"a": 0, "k": [100, 100, 100]},
                    },
                }
            ],
        }
        out = optimize_lottie_payload(lottie, max_comp_edge=1000)
        # 2000→1000 = 0.5
        shape = out["layers"][0]["masksProperties"][0]["pt"]["k"]
        self.assertAlmostEqual(shape["v"][0][0], 50.0)
        self.assertAlmostEqual(shape["v"][0][1], 40.0)
        self.assertAlmostEqual(shape["v"][1][0], 75.0)
        self.assertAlmostEqual(shape["i"][0][1], -5.0)
        self.assertAlmostEqual(shape["o"][0][1], 5.0)
        self.assertAlmostEqual(out["layers"][0]["ks"]["a"]["k"][0], 50.0)

    def test_client_override_rebakes_background_only(self) -> None:
        """Client SSOT for embeds/styles; server always re-bakes background."""
        tiny = _tiny_png_b64()
        override = {
            "v": "5.7.4",
            "w": 64,
            "h": 64,
            "assets": [
                {
                    "id": "asset_head",
                    "w": 1,
                    "h": 1,
                    "u": "",
                    "p": f"data:image/png;base64,{tiny}",
                    "e": 1,
                }
            ],
            "layers": [
                {
                    "ind": 1,
                    "ty": 2,
                    "nm": "head",
                    "refId": "asset_head",
                    "ks": {
                        "o": {"a": 0, "k": 100},
                        "r": {"a": 0, "k": 0},
                        "p": {"a": 0, "k": [32, 32, 0]},
                        "a": {"a": 0, "k": [0.5, 0.5, 0]},
                        "s": {"a": 0, "k": [100, 100, 100]},
                    },
                }
            ],
        }
        out = build_claim_lottie(
            kin_serial="KIN-TEST",
            applied=[],
            background={"theme": "SOLID", "colorHex": "#112233"},
            lottie_override=override,
        )
        names = [L.get("nm") for L in out["layers"]]
        # Client embeds/styles kept; server re-bakes background from payload.
        self.assertEqual(names[0], "head")
        self.assertEqual(names[-1], "background")
        self.assertTrue(out["layers"][-1].get("arcoriClaimBg"))
        self.assertEqual(int(out["w"]), 64)
        self.assertEqual(int(out["h"]), 64)

    def test_addition_keeps_canvas_then_uniform_scales(self) -> None:
        """Full-comp addition PNG must not be independently capped at 512."""
        from PIL import Image
        import base64
        import io
        import tempfile

        # 900×900 canvas with art in the center (transparent padding).
        canvas = Image.new("RGBA", (900, 900), (0, 0, 0, 0))
        for y in range(400, 500):
            for x in range(400, 500):
                canvas.putpixel((x, y), (255, 0, 0, 255))
        buf = io.BytesIO()
        canvas.save(buf, format="PNG")
        png_bytes = buf.getvalue()

        tiny = _tiny_png_b64()
        override = {
            "v": "5.7.4",
            "w": 900,
            "h": 900,
            "assets": [
                {
                    "id": "asset_eye",
                    "w": 1,
                    "h": 1,
                    "u": "",
                    "p": f"data:image/png;base64,{tiny}",
                    "e": 1,
                }
            ],
            "layers": [
                {
                    "ind": 1,
                    "ty": 2,
                    "nm": "left_eye",
                    "refId": "asset_eye",
                    "ks": {
                        "o": {"a": 0, "k": 100},
                        "r": {"a": 0, "k": 0},
                        "p": {"a": 0, "k": [450, 450, 0]},
                        "a": {"a": 0, "k": [0.5, 0.5, 0]},
                        "s": {"a": 0, "k": [100, 100, 100]},
                    },
                }
            ],
        }

        with tempfile.TemporaryDirectory() as tmp:
            png_path = Path(tmp) / "addition.png"
            png_path.write_bytes(png_bytes)
            catalog = {
                "embeds": [
                    {
                        "serial": "KEMB-TEST",
                        "fileName": "addition.png",
                        "imageUrl": "/catalog-media/kin/ser001/00embeds/addition.png",
                        "attachments": [
                            {
                                "kinSerial": "KIN-TEST",
                                "partSerial": "KPART-1",
                                "placement": {"inFrontOf": "left_eye"},
                            }
                        ],
                    }
                ]
            }

            def _fake_path(row: dict) -> Path | None:
                return png_path

            with (
                patch(
                    "modules.avari.kin_lottie_claim_bake.list_kin_embeds",
                    return_value=catalog,
                ),
                patch(
                    "modules.avari.kin_lottie_claim_bake._embed_png_path",
                    side_effect=_fake_path,
                ),
                patch(
                    "modules.avari.kin_lottie_claim_bake.load_template_lottie",
                    return_value=override,
                ),
            ):
                out = build_claim_lottie(
                    kin_serial="KIN-TEST",
                    applied=[
                        {
                            "partSerial": "KPART-1",
                            "customSerial": "CUS-0006",
                            "value": {"KEMB-TEST": {"hue": 0, "lightDark": 0}},
                        }
                    ],
                    background=None,
                    lottie_override=None,
                )

        # Uniform scale 900→768.
        self.assertEqual(out["w"], 768)
        self.assertEqual(out["h"], 768)
        embed_asset = next(
            a for a in out["assets"] if a.get("id") == "asset_embed_KEMB-TEST"
        )
        # Same scale as composition (not capped at 512 independently).
        self.assertEqual(embed_asset["w"], 768)
        self.assertEqual(embed_asset["h"], 768)
        embed_layer = next(
            L for L in out["layers"] if L.get("nm") == "embed_KEMB-TEST"
        )
        # Center of 768 canvas; placement defaults unchanged (no p/s rewrite).
        self.assertAlmostEqual(embed_layer["ks"]["p"]["k"][0], 384.0)
        self.assertAlmostEqual(embed_layer["ks"]["a"]["k"][0], 384.0)

    def test_find_template_under_media_root(self) -> None:
        repo_root = Path(__file__).resolve().parents[5]
        kin_root = repo_root / "assets" / "lottie" / "kin"
        if not (kin_root / "ser001" / "guardians" / "KIN-BRZ-SER001-0001.json").is_file():
            self.skipTest("catalog kin templates not present")
        with patch(
            "modules.avari.kin_lottie_claim_bake.kin_media_root",
            return_value=kin_root,
        ):
            path = find_template_lottie_path("KIN-BRZ-SER001-0001")
        self.assertIsNotNone(path)
        assert path is not None
        self.assertEqual(path.name, "KIN-BRZ-SER001-0001.json")


if __name__ == "__main__":
    unittest.main()
