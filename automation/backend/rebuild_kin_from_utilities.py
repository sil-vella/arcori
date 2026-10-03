#!/usr/bin/env python3
"""Rebuild Kin template Lotties + addition PNGs from designs/kin/00utilities.

All authored PNGs are full-canvas stacks (same w×h per Kin). This script:
  - uniformly downscales every Kin so max(w,h) ≤ [TARGET_MAX_EDGE] (ratio kept)
  - forces every body + addition layer of that Kin to the **same** target size
  - compresses as WebP in Lottie / optimized PNG for embeds
  - rebuilds catalog template JSON with every body layer at p/a=[0,0,0] s=100%
  - replaces addition files under 00embeds + Flutter fallback

Usage (repo root):
  python3 automation/backend/rebuild_kin_from_utilities.py
"""

from __future__ import annotations

import base64
import io
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[2]
UTIL = REPO.parent / "designs" / "kin" / "00utilities"
CATALOG = REPO / "assets" / "lottie" / "kin" / "ser001"
FLUTTER_EMBEDS = REPO / "app_codebase" / "flutter_base_06" / "assets" / "kin" / "embeds" / "ser001"

# Global catalog max edge — same rate for every Kin (ratio preserved).
# 384 ≈ 36% of authored 642² pixels; enough for disc faces, far lighter on GPU.
TARGET_MAX_EDGE = 384
WEBP_QUALITY = 85


@dataclass(frozen=True)
class KinSpec:
    serial: str
    util_dir: Path
    catalog_rel: str
    # suffix tokens (lowercase, normalized) that are additions → 00embeds
    addition_tokens: frozenset[str]
    # map addition token → existing embed output relative path under 00embeds
    addition_out: dict[str, str]


def _target_size(src_w: int, src_h: int, max_edge: int = TARGET_MAX_EDGE) -> tuple[int, int, float]:
    """Return (tw, th, scale) with max(tw,th)=max_edge and src aspect preserved."""
    sw = max(1, int(src_w))
    sh = max(1, int(src_h))
    edge = max(sw, sh)
    if edge <= max_edge:
        return sw, sh, 1.0
    scale = max_edge / float(edge)
    tw = max(1, int(round(sw * scale)))
    th = max(1, int(round(sh * scale)))
    # Keep exact max edge on the long side after rounding.
    if tw >= th:
        tw = max_edge
        th = max(1, int(round(sh * (max_edge / float(sw)))))
    else:
        th = max_edge
        tw = max(1, int(round(sw * (max_edge / float(sh)))))
    return tw, th, scale


def _fit_rgba(img: Image.Image, tw: int, th: int) -> Image.Image:
    """Resize to exact [tw]×[th] (LANCZOS). Same dims for every layer of a Kin."""
    rgba = img.convert("RGBA")
    if rgba.size == (tw, th):
        return rgba
    return rgba.resize((tw, th), Image.Resampling.LANCZOS)


def _norm_token(raw: str) -> str:
    s = raw.lower().strip()
    s = s.replace("=", "-")
    s = re.sub(r"[^a-z0-9]+", "_", s)
    s = re.sub(r"_+", "_", s).strip("_")
    # common typos / aliases
    aliases = {
        "eeyes": "eyes",
        "eyee": "eyes",
        "eye": "eyes",
        "leye": "eyes",
        "righhtarm": "right_arm",
        "rightarm": "right_arm",
        "leftarm": "left_arm",
        "rightarn": "right_arm",
        "right_arn": "right_arm",
        "leefetleeg": "left_leg",
        "leftleg": "left_leg",
        "rightleg": "right_leg",
        "lefteyebrow": "left_eyebrow",
        "righteyebrow": "right_eyebrow",
        "leftbrow": "left_eyebrow",
        "rightbrow": "right_eyebrow",
        "head_mouth_hair_antlers": "head",
        "head_mouth_hair_horns": "head",
        "metallic_rose_background": "metallic_plate",
        "metallicrosebackground": "metallic_plate",
        "torso_with_lower_tail": "body",
        "body_with_lower_tail": "body",
        "cheek": "cheeks",
        "right_cheek": "right_cheek",
        "left_cheek": "left_cheek",
    }
    return aliases.get(s, s)


def _parse_layered_name(path: Path) -> tuple[int, str] | None:
    """Return (order_index, normalized_token) from layered export filename."""
    stem = path.stem
    # Outer export index (front→back). Nested re-exports may look like
    # droplet_layered_0005_droplet_layered_0003_right_eyebrow.
    m = re.search(r"(?:layered|ayered)_(\d+)(?:_(.+))?$", stem, re.I)
    if not m:
        return None
    idx = int(m.group(1))
    rest = m.group(2) or ""
    # Peel nested *_layered_NNNN_ prefixes until the leaf label remains.
    while True:
        nested = re.match(r".*?(?:layered|ayered)_(\d+)_(.+)$", rest, re.I)
        if not nested:
            break
        rest = nested.group(2)
    # strip leading NN- / NN= / NN-N- ordinals like 01-1-cap / 09=rightarm
    rest = re.sub(r"^\d+(?:-\d+)?[-_=]", "", rest)
    # guardian additions embed kin serial in name
    if "KIN-" in rest:
        # ..._KIN-BRZ-..._0000_halo → halo
        tail = rest.split("_")[-1]
        return idx, _norm_token(tail)
    return idx, _norm_token(rest)


def _compress_rgba(img: Image.Image) -> tuple[bytes, str]:
    """Return (bytes, mime_subtype) — WebP, same pixel size."""
    buf = io.BytesIO()
    img.save(buf, format="WEBP", quality=WEBP_QUALITY, method=4)
    return buf.getvalue(), "webp"


def _compress_png_file(img: Image.Image) -> bytes:
    """Optimized PNG, same pixel size (for on-disk embed catalog)."""
    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True, compress_level=9)
    return buf.getvalue()


def _fullbleed_layer(
    *,
    ind: int,
    nm: str,
    ref_id: str,
    op: float = 30.0,
) -> dict:
    return {
        "ddd": 0,
        "ind": ind,
        "ty": 2,
        "nm": nm,
        "refId": ref_id,
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
        "op": op,
        "st": 0,
        "bm": 0,
    }


def _build_lottie(
    *,
    serial: str,
    w: int,
    h: int,
    # front → back (AE list order): list of (layer_nm, rgba_image)
    stacked: list[tuple[str, Image.Image]],
) -> dict:
    assets: list[dict] = []
    layers: list[dict] = []
    for i, (nm, img) in enumerate(stacked):
        if img.size != (w, h):
            raise ValueError(f"{nm} size {img.size} != comp {(w, h)}")
        raw, subtype = _compress_rgba(img)
        data_url = f"data:image/{subtype};base64,{base64.b64encode(raw).decode('ascii')}"
        asset_id = f"asset_{nm}"
        assets.append({"id": asset_id, "w": w, "h": h, "u": "", "p": data_url, "e": 1})
        layers.append(_fullbleed_layer(ind=i + 1, nm=nm, ref_id=asset_id))
    return {
        "v": "5.7.4",
        "fr": 30,
        "ip": 0,
        "op": 30,
        "w": w,
        "h": h,
        "nm": serial,
        "ddd": 0,
        "assets": assets,
        "layers": layers,
        "meta": {
            "g": "arcori kin utilities rebuild",
            "kinSerial": serial,
            "maxEdge": TARGET_MAX_EDGE,
        },
    }


# Addition token → relative path under 00embeds (and Flutter embeds/ser001)
ADDITION_MAP: dict[str, dict[str, str]] = {
    # Entelairs
    "KIN-ALC-SER001-0005": {
        "rose": "entelairs/ALC/KIN-ALC-SER001-0005_0000_rose.png",
        "wings": "entelairs/ALC/KIN-ALC-SER001-0005_0000_wings.png",
        "tiara": "entelairs/ALC/KIN-ALC-SER001-0005_0001_tiara.png",
        "necklace": "entelairs/ALC/KIN-ALC-SER001-0005_0002_necklace.png",
    },
    "KIN-ASP-SER001-0006": {
        "wings": "entelairs/ASP/KIN-ASP-SER001-0006_0000_wings.png",
        "rose": "entelairs/ASP/KIN-ASP-SER001-0006_0001_rose.png",
        "tiara": "entelairs/ASP/KIN-ASP-SER001-0006_0002_tiara.png",
    },
    "KIN-HGD-SER001-0007": {
        "helmet": "entelairs/HGD/KIN-HGD-SER001-0007_0000_helmet.png",
        "shield": "entelairs/HGD/KIN-HGD-SER001-0007_0001_shield.png",
        "wings": "entelairs/HGD/KIN-HGD-SER001-0007_0002_wings.png",
    },
    "KIN-HMG-SER001-0008": {
        "hatchet": "entelairs/HMG/KIN-HMG-SER001-0008_0000_hatchet.png",
        "shield": "entelairs/HMG/KIN-HMG-SER001-0008_0001_shield.png",
        "wings": "entelairs/HMG/KIN-HMG-SER001-0008_0002_wings.png",
    },
    # Guardians
    "KIN-BRZ-SER001-0001": {
        "halo": "guardians/BRZ/KIN-BRZ-SER001-0001_0000_halo.png",
        "lightning": "guardians/BRZ/KIN-BRZ-SER001-0001_0001_lightning.png",
        "ball": "guardians/BRZ/KIN-BRZ-SER001-0001_0002_ball.png",
    },
    "KIN-GLD-SER001-0002": {
        "halo": "guardians/GLD/KIN-GLD-SER001-0002_0000_halo.png",
        "lightning_eyes": "guardians/GLD/KIN-GLD-SER001-0002_0001_lightning-eyes.png",
        "spear": "guardians/GLD/KIN-GLD-SER001-0002_0003_spear.png",
    },
    "KIN-IVY-SER001-0003": {
        "halo": "guardians/IVY/KIN-IVY-SER001-0003_0000_halo.png",
        "lightning_eyes": "guardians/IVY/KIN-IVY-SER001-0003_0001_lightning-eyes.png",
        "spear": "guardians/IVY/KIN-IVY-SER001-0003_0003_spear.png",
    },
    "KIN-SLV-SER001-0004": {
        "halo": "guardians/SLV/KIN-SLV-SER001-0004_0000_halo.png",
        "lightning": "guardians/SLV/KIN-SLV-SER001-0004_0001_lightning.png",
        "ball": "guardians/SLV/KIN-SLV-SER001-0004_0002_ball.png",
    },
}

# (serial, util relative dir, catalog relative json)
KIN_DIRS: list[tuple[str, str, str]] = [
    ("KIN-ALC-SER001-0005", "entelairs/ALC", "entelairs/KIN-ALC-SER001-0005.json"),
    ("KIN-ASP-SER001-0006", "entelairs/ASP", "entelairs/KIN-ASP-SER001-0006.json"),
    ("KIN-HGD-SER001-0007", "entelairs/HGD", "entelairs/KIN-HGD-SER001-0007.json"),
    ("KIN-HMG-SER001-0008", "entelairs/HMG", "entelairs/KIN-HMG-SER001-0008.json"),
    ("KIN-BRZ-SER001-0001", "guardians/bronze", "guardians/KIN-BRZ-SER001-0001.json"),
    ("KIN-GLD-SER001-0002", "guardians/gold", "guardians/KIN-GLD-SER001-0002.json"),
    ("KIN-IVY-SER001-0003", "guardians/ivory", "guardians/KIN-IVY-SER001-0003.json"),
    ("KIN-SLV-SER001-0004", "guardians/silver", "guardians/KIN-SLV-SER001-0004.json"),
    ("KIN-CLD-SER001-0009", "walkies/cloud", "walkies/KIN-CLD-SER001-0009.json"),
    ("KIN-CRY-SER001-0010", "walkies/crystal", "walkies/KIN-CRY-SER001-0010.json"),
    ("KIN-DRP-SER001-0011", "walkies/droplet", "walkies/KIN-DRP-SER001-0011.json"),
    ("KIN-FIR-SER001-0012", "walkies/fire", "walkies/KIN-FIR-SER001-0012.json"),
    ("KIN-MON-SER001-0013", "walkies/moon", "walkies/KIN-MON-SER001-0013.json"),
    ("KIN-RBT-SER001-0014", "walkies/robot", "walkies/KIN-RBT-SER001-0014.json"),
    ("KIN-SPR-SER001-0015", "walkies/sprout", "walkies/KIN-SPR-SER001-0015.json"),
    ("KIN-STR-SER001-0016", "walkies/star", "walkies/KIN-STR-SER001-0016.json"),
    ("KIN-WTR-SER001-0017", "walkies/water", "walkies/KIN-WTR-SER001-0017.json"),
    ("KIN-PLN-SER001-0018", "walkies/planet", "walkies/KIN-PLN-SER001-0018.json"),
]

WALKIE_ADDITION_TOKENS = frozenset(
    {"cap", "glasses", "cup", "controller", "tongue"}
)
# Tokens that are never body (skip Hue_Saturation junk)
SKIP_TOKENS = frozenset(
    {
        "hue_saturation_1",
        "hue_saturation_1_copy",
        "hue_saturation_1_copy_2",
        "hue_saturation_1_copy_3",
    }
)


def _is_addition(serial: str, token: str) -> bool:
    if token in SKIP_TOKENS:
        return False
    amap = ADDITION_MAP.get(serial) or {}
    if token in amap:
        return True
    # lightning-eyes filename normalizes to lightning_eyes
    if token.replace("-", "_") in amap:
        return True
    if serial.startswith("KIN-") and serial.split("-")[1] in {
        "CLD",
        "CRY",
        "FIR",
        "MON",
        "RBT",
        "SPR",
        "STR",
        "WTR",
        "PLN",
        "DRP",
    }:
        return token in WALKIE_ADDITION_TOKENS
    return False


def _addition_rel(serial: str, token: str) -> str | None:
    amap = ADDITION_MAP.get(serial) or {}
    if token in amap:
        return amap[token]
    t2 = token.replace("-", "_")
    if t2 in amap:
        return amap[t2]
    # walkie extras → 00embeds/walkies/{CODE}/...
    code = serial.split("-")[1]
    if token in WALKIE_ADDITION_TOKENS:
        return f"walkies/{code}/{serial}_{token}.png"
    return None


def _body_layer_name(token: str) -> str | None:
    if token in SKIP_TOKENS or token in WALKIE_ADDITION_TOKENS:
        return None
    # already normalized aliases
    if token in {
        "eyes",
        "head",
        "body",
        "left_arm",
        "right_arm",
        "left_leg",
        "right_leg",
        "torso",
        "left_eyebrow",
        "right_eyebrow",
        "cheeks",
        "left_cheek",
        "right_cheek",
        "left_eye",
        "right_eye",
        "metallic_plate",
    }:
        return token
    return token  # keep unknown body-ish names


def process_kin(serial: str, util_rel: str, catalog_rel: str) -> dict:
    folder = UTIL / util_rel
    if not folder.is_dir():
        return {"serial": serial, "error": f"missing {folder}"}

    parsed: list[tuple[int, str, Path]] = []
    for path in sorted(folder.glob("*.png")):
        meta = _parse_layered_name(path)
        if meta is None:
            continue
        idx, token = meta
        if token in SKIP_TOKENS or token.startswith("hue_saturation"):
            continue
        parsed.append((idx, token, path))

    if not parsed:
        return {"serial": serial, "error": "no pngs parsed"}

    # Prefer dominant canvas size for **body** layers only.
    sizes: dict[tuple[int, int], int] = {}
    for _, token, path in parsed:
        if _is_addition(serial, token):
            continue
        with Image.open(path) as im:
            sizes[im.size] = sizes.get(im.size, 0) + 1
    if not sizes:
        # all additions? fall back to any
        for _, _, path in parsed:
            with Image.open(path) as im:
                sizes[im.size] = sizes.get(im.size, 0) + 1
    comp_wh = max(sizes.items(), key=lambda kv: kv[1])[0]
    src_w, src_h = comp_wh
    tw, th, scale = _target_size(src_w, src_h)

    body_stack: list[tuple[str, Image.Image]] = []
    additions_written: list[str] = []
    seen_body: set[str] = set()

    # Sort front→back by index ascending (Photoshop export order)
    parsed.sort(key=lambda t: t[0])

    for idx, token, path in parsed:
        if _is_addition(serial, token):
            rel = _addition_rel(serial, token)
            if not rel:
                continue
            img = _fit_rgba(Image.open(path), tw, th)
            raw = _compress_png_file(img)
            for root in (CATALOG / "00embeds", FLUTTER_EMBEDS):
                out = root / rel
                out.parent.mkdir(parents=True, exist_ok=True)
                out.write_bytes(raw)
            additions_written.append(rel)
            continue

        with Image.open(path) as im:
            if im.size != comp_wh:
                continue
        layer_nm = _body_layer_name(token)
        if layer_nm is None:
            continue
        if layer_nm in seen_body:
            continue
        seen_body.add(layer_nm)
        body_stack.append((layer_nm, _fit_rgba(Image.open(path), tw, th)))

    if not body_stack:
        return {"serial": serial, "error": "no body layers", "additions": additions_written}

    # Metallic plate must be bottom-most (last in AE list)
    metal = [(n, p) for n, p in body_stack if n == "metallic_plate"]
    rest = [(n, p) for n, p in body_stack if n != "metallic_plate"]
    body_stack = rest + metal

    lottie = _build_lottie(serial=serial, w=tw, h=th, stacked=body_stack)
    out_path = CATALOG / catalog_rel
    out_path.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(lottie, ensure_ascii=False, separators=(",", ":"))
    out_path.write_text(text, encoding="utf-8")

    return {
        "serial": serial,
        "src": f"{src_w}x{src_h}",
        "comp": f"{tw}x{th}",
        "scale": round(scale, 4),
        "layers": [n for n, _ in body_stack],
        "bytes_kb": round(out_path.stat().st_size / 1024),
        "additions": additions_written,
        "path": str(out_path.relative_to(REPO)),
    }


def main() -> int:
    if not UTIL.is_dir():
        print(f"missing utilities dir: {UTIL}", file=sys.stderr)
        return 1

    print(f"UTIL={UTIL}")
    print(f"CATALOG={CATALOG}")
    print(f"TARGET_MAX_EDGE={TARGET_MAX_EDGE}")
    results = []
    for serial, util_rel, catalog_rel in KIN_DIRS:
        r = process_kin(serial, util_rel, catalog_rel)
        results.append(r)
        if r.get("error"):
            print(f"FAIL {serial}: {r['error']}")
        else:
            print(
                f"OK  {serial}  {r['src']}→{r['comp']}  scale={r['scale']}  "
                f"layers={len(r['layers'])}  {r['bytes_kb']}KB  "
                f"embeds={len(r['additions'])}"
            )

    report = CATALOG / "_rebuild_from_utilities_report.json"
    report.write_text(json.dumps(results, indent=2), encoding="utf-8")
    print(f"\nWrote {report.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
