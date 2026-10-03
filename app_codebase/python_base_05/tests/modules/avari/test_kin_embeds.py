"""Kin embed hot catalog (embeds.json under CATALOG_KIN_MEDIA_ROOT)."""

from __future__ import annotations

import json
import os
import tempfile
import unittest
from pathlib import Path

from modules.avari.kin_embeds import list_kin_embeds


class KinEmbedsTests(unittest.TestCase):
    def test_list_reads_catalog_and_skips_missing_files(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            embeds = root / "ser001" / "00embeds"
            embeds.mkdir(parents=True)
            png = embeds / "guardians" / "BRZ" / "halo.png"
            png.parent.mkdir(parents=True)
            png.write_bytes(b"\x89PNG")
            catalog = {
                "version": 1,
                "embeds": [
                    {
                        "serial": "KEMB-T1",
                        "displayName": "Test halo",
                        "fileName": "guardians/BRZ/halo.png",
                        "attachments": [
                            {
                                "kinSerial": "KIN-BRZ-SER001-0001",
                                "partSerial": "KPART-0003",
                                "placement": {"inFrontOf": "left_eye"},
                            }
                        ],
                    },
                    {
                        "serial": "KEMB-MISSING",
                        "displayName": "Gone",
                        "fileName": "guardians/BRZ/nope.png",
                        "attachments": [
                            {
                                "kinSerial": "KIN-X",
                                "partSerial": "KPART-X",
                                "placement": {"inFrontOf": "head"},
                            }
                        ],
                    },
                    {
                        "serial": "KEMB-BAD-PLACE",
                        "displayName": "Bad",
                        "fileName": "guardians/BRZ/halo.png",
                        "attachments": [
                            {
                                "kinSerial": "KIN-X",
                                "partSerial": "KPART-X",
                                "placement": {
                                    "inFrontOf": "a",
                                    "behindLayer": "b",
                                },
                            }
                        ],
                    },
                ],
            }
            (embeds / "embeds.json").write_text(
                json.dumps(catalog), encoding="utf-8"
            )
            prev = os.environ.get("CATALOG_KIN_MEDIA_ROOT")
            os.environ["CATALOG_KIN_MEDIA_ROOT"] = str(root)
            try:
                data = list_kin_embeds()
            finally:
                if prev is None:
                    os.environ.pop("CATALOG_KIN_MEDIA_ROOT", None)
                else:
                    os.environ["CATALOG_KIN_MEDIA_ROOT"] = prev

            self.assertEqual(len(data["embeds"]), 1)
            row = data["embeds"][0]
            self.assertEqual(row["serial"], "KEMB-T1")
            self.assertTrue(
                row["imageUrl"].endswith("/guardians/BRZ/halo.png")
            )
            self.assertEqual(len(row["attachments"]), 1)
            self.assertEqual(
                row["attachments"][0]["placement"]["inFrontOf"], "left_eye"
            )

    def test_missing_catalog_returns_empty(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            prev = os.environ.get("CATALOG_KIN_MEDIA_ROOT")
            os.environ["CATALOG_KIN_MEDIA_ROOT"] = tmp
            try:
                data = list_kin_embeds()
            finally:
                if prev is None:
                    os.environ.pop("CATALOG_KIN_MEDIA_ROOT", None)
                else:
                    os.environ["CATALOG_KIN_MEDIA_ROOT"] = prev
            self.assertEqual(data["embeds"], [])


if __name__ == "__main__":
    unittest.main()
