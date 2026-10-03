"""Each Kin template + all catalog additions: canvas sizes stay aligned."""

from __future__ import annotations

import base64
import json
import struct
import unittest
from pathlib import Path
from unittest.mock import patch

from modules.avari.kin_lottie_claim_bake import (
    bake_embeds_into_lottie,
    build_claim_lottie,
    find_template_lottie_path,
)

_REPO = Path(__file__).resolve().parents[5]
_KIN_ROOT = _REPO / "assets" / "lottie" / "kin"
_EMBEDS_JSON = _KIN_ROOT / "ser001" / "00embeds" / "embeds.json"
_EMBEDS_DIR = _KIN_ROOT / "ser001" / "00embeds"


def _png_size(raw: bytes) -> tuple[int, int]:
    return struct.unpack(">II", raw[16:24])


def _asset_meta_and_bytes(asset: dict) -> tuple[int, int, tuple[int, int] | None]:
    aw, ah = int(asset.get("w") or 0), int(asset.get("h") or 0)
    p = asset.get("p")
    if not (isinstance(p, str) and p.startswith("data:image/") and ";base64," in p):
        return aw, ah, None
    try:
        raw = base64.b64decode(p.split(",", 1)[1], validate=False)
    except Exception:
        return aw, ah, None
    if raw[:4] == b"\x89PNG":
        return aw, ah, _png_size(raw)
    try:
        from PIL import Image
        import io

        im = Image.open(io.BytesIO(raw))
        return aw, ah, im.size
    except Exception:
        return aw, ah, None


@unittest.skipUnless(_EMBEDS_JSON.is_file(), "catalog embeds.json missing")
class TestKinAdditionBakeSizes(unittest.TestCase):
    def test_every_kin_all_additions_match_template_then_uniform_scale(self) -> None:
        embeds = json.loads(_EMBEDS_JSON.read_text(encoding="utf-8"))["embeds"]
        by_kin: dict[str, list[dict]] = {}
        for row in embeds:
            if not isinstance(row, dict):
                continue
            for att in row.get("attachments") or []:
                if not isinstance(att, dict):
                    continue
                kin = str(att.get("kinSerial") or "").strip()
                if kin:
                    by_kin.setdefault(kin, []).append(row)

        self.assertGreaterEqual(len(by_kin), 1)

        with patch(
            "modules.avari.kin_lottie_claim_bake.kin_media_root",
            return_value=_KIN_ROOT,
        ):
            for kin in sorted(by_kin):
                with self.subTest(kin=kin):
                    self._assert_kin(kin, by_kin[kin])

    def _assert_kin(self, kin: str, rows_in: list[dict]) -> None:
        seen: set[str] = set()
        rows: list[dict] = []
        for row in rows_in:
            serial = str(row.get("serial") or "")
            if not serial or serial in seen:
                continue
            seen.add(serial)
            rows.append(row)

        path = find_template_lottie_path(kin)
        self.assertIsNotNone(path, f"template missing for {kin}")
        assert path is not None
        template = json.loads(path.read_text(encoding="utf-8"))
        tw, th = int(template["w"]), int(template["h"])

        for row in rows:
            fp = _EMBEDS_DIR / str(row["fileName"])
            self.assertTrue(fp.is_file(), f"missing {fp}")
            sw, sh = _png_size(fp.read_bytes())
            self.assertEqual(
                (sw, sh),
                (tw, th),
                f"{row['serial']}: source {sw}x{sh} != template {tw}x{th}",
            )

        catalog = {
            "embeds": [
                {
                    **row,
                    "imageUrl": (
                        f"/catalog-media/kin/ser001/00embeds/{row['fileName']}"
                    ),
                }
                for row in rows
            ]
        }
        value = {str(r["serial"]): {"hue": 0, "lightDark": 0} for r in rows}
        part = next(
            str(att.get("partSerial") or "")
            for r in rows
            for att in (r.get("attachments") or [])
            if isinstance(att, dict) and att.get("kinSerial") == kin
        )
        applied = [
            {"partSerial": part, "customSerial": "CUS-0006", "value": value}
        ]

        def _fake_path(row: dict) -> Path | None:
            p = _EMBEDS_DIR / str(row.get("fileName") or "")
            return p if p.is_file() else None

        with (
            patch(
                "modules.avari.kin_lottie_claim_bake.list_kin_embeds",
                return_value=catalog,
            ),
            patch(
                "modules.avari.kin_lottie_claim_bake._embed_png_path",
                side_effect=_fake_path,
            ),
        ):
            pre = bake_embeds_into_lottie(
                json.loads(path.read_text(encoding="utf-8")),
                kin_serial=kin,
                applied=applied,
            )
            out = build_claim_lottie(
                kin_serial=kin,
                applied=applied,
                background={"theme": "SOLID", "colorHex": "#2A2A2E"},
                lottie_override=json.loads(path.read_text(encoding="utf-8")),
            )

        pre_embeds = [
            a
            for a in (pre.get("assets") or [])
            if isinstance(a, dict)
            and str(a.get("id") or "").startswith("asset_embed_")
        ]
        out_embeds = [
            a
            for a in (out.get("assets") or [])
            if isinstance(a, dict)
            and str(a.get("id") or "").startswith("asset_embed_")
        ]
        self.assertEqual(len(pre_embeds), len(rows))
        self.assertEqual(len(out_embeds), len(rows))

        for asset in pre_embeds:
            aw, ah, real = _asset_meta_and_bytes(asset)
            self.assertEqual((aw, ah), (tw, th))
            if real is not None:
                self.assertEqual(real, (aw, ah))

        square = max(tw, th)
        final_side = min(square, 768)
        scale = final_side / float(square)
        expect_ew = max(1, int(round(tw * scale)))
        expect_eh = max(1, int(round(th * scale)))

        for asset in out_embeds:
            sid = str(asset.get("id") or "").replace("asset_embed_", "")
            aw, ah, real = _asset_meta_and_bytes(asset)
            self.assertEqual(
                (aw, ah),
                (expect_ew, expect_eh),
                f"{kin}/{sid} claim size",
            )
            if real is not None:
                self.assertEqual(real, (aw, ah))
            layer = next(
                L
                for L in (out.get("layers") or [])
                if isinstance(L, dict) and L.get("nm") == f"embed_{sid}"
            )
            anchor = layer["ks"]["a"]["k"]
            self.assertAlmostEqual(float(anchor[0]), aw / 2.0, delta=1.5)
            self.assertAlmostEqual(float(anchor[1]), ah / 2.0, delta=1.5)
            scale_pct = layer["ks"]["s"]["k"]
            self.assertAlmostEqual(float(scale_pct[0]), 100.0, places=2)
            self.assertAlmostEqual(float(scale_pct[1]), 100.0, places=2)


if __name__ == "__main__":
    unittest.main()
