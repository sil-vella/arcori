"""Face media (webp / lottie) for any theme — not Kin-only."""

from __future__ import annotations

import unittest

from modules.catalog.catalog_service import _attach_face_media, design_summary


class FaceMediaTests(unittest.TestCase):
    def test_design_summary_passes_regular_lottie(self) -> None:
        design = {
            "internalId": "ANM-TIG-SER001-GEN001-0001",
            "themeCode": "ANM",
            "theme": "Animals",
            "design": "Tiger",
            "faceMedia": "lottie",
            "lottieUrl": "/catalog-media/example/tiger.json",
            "color": "#C6A15B",
            "generation": {"roman": "I", "number": 1},
        }
        out = design_summary(design, series_key="Genesis", theme="Animals")
        self.assertEqual(out["faceMedia"], "lottie")
        self.assertEqual(out["lottieUrl"], "/catalog-media/example/tiger.json")
        self.assertTrue(str(out.get("imageUrl") or "").endswith(".webp"))

    def test_attach_face_media_regular_lottie_url_only(self) -> None:
        out = {
            "internalId": "ANM-OWL-SER001-GEN001-0002",
            "themeCode": "ANM",
            "theme": "Animals",
            "lottieUrl": " /media/custom/owl.json ",
            "imageUrl": "/catalog-media/001_genesis/animals/ANM-OWL-SER001-0002.webp",
        }
        _attach_face_media(out, "ANM-OWL-SER001-GEN001-0002")
        self.assertEqual(out["faceMedia"], "lottie")
        self.assertEqual(out["lottieUrl"], "/media/custom/owl.json")

    def test_attach_face_media_webp_default(self) -> None:
        out = {
            "internalId": "ANM-TIG-SER001-GEN001-0001",
            "themeCode": "ANM",
            "theme": "Animals",
            "imageUrl": "/catalog-media/001_genesis/animals/ANM-TIG-SER001-0001.webp",
        }
        _attach_face_media(out, "ANM-TIG-SER001-GEN001-0001")
        self.assertEqual(out["faceMedia"], "webp")
        self.assertNotIn("lottieUrl", out)


if __name__ == "__main__":
    unittest.main()
