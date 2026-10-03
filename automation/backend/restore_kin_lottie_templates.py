#!/usr/bin/env python3
"""Restore catalog Kin template Lotties from designs/kin/00utilities originals.

The Sep 27 shrink script resized PNGs and composition with **different** scale
factors, which broke layer anchors/positions. Source layered JSON under
``designs/kin/00utilities`` is untouched.

Entelair catalog templates also need a full-canvas ``metallic_plate`` layer
(copper plate) for claim BG bake — added from ``metallic-rose-background.webp``.

Usage (repo root of app_dev_fastapi_postgres):
  python3 automation/backend/restore_kin_lottie_templates.py
"""

from __future__ import annotations

import base64
import io
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DESIGNS = REPO.parent / "designs" / "kin" / "00utilities"
CATALOG = REPO / "assets" / "lottie" / "kin" / "ser001"

# design relative path → catalog relative path
MAP: list[tuple[str, str]] = [
    ("guardians/bronze_genie_layered (3).json", "guardians/KIN-BRZ-SER001-0001.json"),
    ("guardians/gold_genie_layered.json", "guardians/KIN-GLD-SER001-0002.json"),
    ("guardians/ivory_genie_layered.json", "guardians/KIN-IVY-SER001-0003.json"),
    ("guardians/silver_genie_layered.json", "guardians/KIN-SLV-SER001-0004.json"),
    ("entelairs/antler_lace_layered.json", "entelairs/KIN-ALC-SER001-0005.json"),
    ("entelairs/antler_spirit_layered.json", "entelairs/KIN-ASP-SER001-0006.json"),
    ("entelairs/horned_guardian_layered.json", "entelairs/KIN-HGD-SER001-0007.json"),
    ("entelairs/horned_mage_layered.json", "entelairs/KIN-HMG-SER001-0008.json"),
    ("walkies/cloud_character_layered.json", "walkies/KIN-CLD-SER001-0009.json"),
    ("walkies/crystal_character_layered.json", "walkies/KIN-CRY-SER001-0010.json"),
    ("walkies/droplet_character_layered.json", "walkies/KIN-DRP-SER001-0011.json"),
    ("walkies/fire_character_layered.json", "walkies/KIN-FIR-SER001-0012.json"),
    ("walkies/moon_character_layered.json", "walkies/KIN-MON-SER001-0013.json"),
    ("walkies/robot_character_layered.json", "walkies/KIN-RBT-SER001-0014.json"),
    ("walkies/sprout_character_layered.json", "walkies/KIN-SPR-SER001-0015.json"),
    ("walkies/star_character_layered.json", "walkies/KIN-STR-SER001-0016.json"),
    ("walkies/water_character_layered.json", "walkies/KIN-WTR-SER001-0017.json"),
    ("walkies/planet_character_layered.json", "walkies/KIN-PLN-SER001-0018.json"),
]

ENTELAIR_SERIALS = {
    "KIN-ALC-SER001-0005",
    "KIN-ASP-SER001-0006",
    "KIN-HGD-SER001-0007",
    "KIN-HMG-SER001-0008",
}

PLATE_WEBP = (
    DESIGNS
    / "entelairs"
    / "parts"
    / "horned_coat_ghost_complete_parts"
    / "metallic-rose-background.webp"
)


def _cover_resize(img, w: int, h: int):
    from PIL import Image

    sw, sh = img.size
    scale = max(w / max(sw, 1), h / max(sh, 1))
    nw, nh = max(1, int(sw * scale)), max(1, int(sh * scale))
    resized = img.resize((nw, nh), Image.Resampling.LANCZOS)
    left = max(0, (nw - w) // 2)
    top = max(0, (nh - h) // 2)
    return resized.crop((left, top, left + w, top + h))


def _inject_metallic_plate(lottie: dict) -> None:
    from PIL import Image

    if not PLATE_WEBP.is_file():
        raise FileNotFoundError(f"missing plate art {PLATE_WEBP}")

    w = max(1, int(lottie.get("w") or 512))
    h = max(1, int(lottie.get("h") or 512))
    assets = list(lottie.get("assets") or [])
    layers = list(lottie.get("layers") or [])
    lottie["assets"] = assets
    lottie["layers"] = layers

    # Drop any prior plate / legacy background image layer.
    drop_nm = {"metallic_plate", "background"}
    drop_ids = {
        str(L.get("refId") or "")
        for L in layers
        if isinstance(L, dict) and str(L.get("nm") or "") in drop_nm
    }
    layers[:] = [
        L
        for L in layers
        if not (isinstance(L, dict) and str(L.get("nm") or "") in drop_nm)
    ]
    assets[:] = [
        a
        for a in assets
        if not (isinstance(a, dict) and str(a.get("id") or "") in drop_ids)
    ]

    src = Image.open(PLATE_WEBP).convert("RGBA")
    fitted = _cover_resize(src, w, h)
    buf = io.BytesIO()
    fitted.save(buf, format="PNG", optimize=True)
    data_url = f"data:image/png;base64,{base64.b64encode(buf.getvalue()).decode('ascii')}"

    asset_id = "asset_metallic_plate"
    assets.append(
        {"id": asset_id, "w": w, "h": h, "u": "", "p": data_url, "e": 1}
    )

    max_ind = 0
    max_op = 30.0
    for layer in layers:
        if not isinstance(layer, dict):
            continue
        ind = layer.get("ind")
        if isinstance(ind, int) and ind > max_ind:
            max_ind = ind
        op = layer.get("op")
        if isinstance(op, (int, float)) and float(op) > max_op:
            max_op = float(op)

    # Bottom of list = behind other layers in Lottie.
    layers.append(
        {
            "ddd": 0,
            "ind": max_ind + 1,
            "ty": 2,
            "nm": "metallic_plate",
            "refId": asset_id,
            "sr": 1,
            "ks": {
                "o": {"a": 0, "k": 100},
                "r": {"a": 0, "k": 0},
                "p": {"a": 0, "k": [0, 0, 0]},
                "a": {"a": 0, "k": [0, 0, 0]},
                "s": {"a": 0, "k": [100, 100, 100]},
            },
            "ao": 0,
            "ip": 0,
            "op": max_op,
            "st": 0,
            "bm": 0,
        }
    )


def main() -> int:
    if not DESIGNS.is_dir():
        print(f"missing designs root: {DESIGNS}", file=sys.stderr)
        return 1
    if not CATALOG.is_dir():
        print(f"missing catalog root: {CATALOG}", file=sys.stderr)
        return 1

    for src_rel, dst_rel in MAP:
        src = DESIGNS / src_rel
        dst = CATALOG / dst_rel
        if not src.is_file():
            print(f"SKIP missing {src}")
            continue
        data = json.loads(src.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            print(f"SKIP bad json {src}")
            continue
        serial = dst.stem
        if serial in ENTELAIR_SERIALS:
            _inject_metallic_plate(data)
        dst.parent.mkdir(parents=True, exist_ok=True)
        # Pretty enough for diffs; claim bake still optimizes on write.
        dst.write_text(
            json.dumps(data, ensure_ascii=False, separators=(",", ":")),
            encoding="utf-8",
        )
        names = [L.get("nm") for L in data.get("layers") or [] if isinstance(L, dict)]
        print(
            f"OK {dst.relative_to(REPO)}  {data.get('w')}x{data.get('h')}  "
            f"{dst.stat().st_size/1024:.0f}KB  layers={names}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
