"""Bake selectable Kin claim backgrounds into Lottie JSON (all Kin types).

Entelair templates may ship a metallic copper plate as ``nm=background``.
That plate is renamed to ``metallic_plate`` so the claim background owns the
``background`` layer slot. Guardians/walkies get a ``background`` layer injected.
"""

from __future__ import annotations

import base64
import io
import math
import os
from pathlib import Path
from typing import Any

from core.utils.dev_logger import customlog

LOGGING_SWITCH = True

_ASSET_ID = "asset_background"
_LAYER_BG = "background"
_LAYER_METALLIC = "metallic_plate"
_PUBLIC_PREFIX = "/catalog-media/kin/ser001/00backgrounds"

# Cap claim-BG rasters for all templates (tall Entelair square-pad can be ~1400²).
# Layer ks.s compensates so the asset still covers the full composition.
MAX_BG_BAKE_EDGE = 384


def bake_claim_background_into_lottie(
    lottie: dict[str, Any],
    background: dict[str, Any] | None,
) -> dict[str, Any]:
    """Return a copy of [lottie] with claim [background] baked as bottom layer."""
    if not isinstance(lottie, dict):
        return lottie
    if not isinstance(background, dict) or not background:
        return lottie

    out = dict(lottie)
    assets = list(out.get("assets") or [])
    layers = list(out.get("layers") or [])
    out["assets"] = assets
    out["layers"] = layers

    _promote_existing_background_to_metallic(layers, assets)
    # Tall Entelair canvases letterbox in circular discs; square so BG fills.
    w, h = _expand_to_square_canvas(out, layers)
    bake_w, bake_h, scale_pct = _bake_raster_size(w, h)

    png_b64 = _rasterize_background(background, w=bake_w, h=bake_h)
    if not png_b64:
        if LOGGING_SWITCH:
            customlog("avari: kin bg bake skipped (no raster)")
        return out

    data_url = f"data:image/webp;base64,{png_b64}"
    _upsert_background_asset(assets, data_url=data_url, w=bake_w, h=bake_h)
    _upsert_background_layer(layers, scale_pct=scale_pct)

    if LOGGING_SWITCH:
        theme = str(background.get("theme") or "")
        customlog(
            f"avari: kin bg baked into lottie theme={theme} "
            f"comp={w}x{h} bake={bake_w}x{bake_h} scale={scale_pct:.1f}%"
        )
    return out


def _bake_raster_size(w: int, h: int) -> tuple[int, int, float]:
    """Return (bake_w, bake_h, layer_scale_pct) capped at [MAX_BG_BAKE_EDGE]."""
    ww = max(1, int(w))
    hh = max(1, int(h))
    edge = max(ww, hh)
    if edge <= MAX_BG_BAKE_EDGE:
        return ww, hh, 100.0
    s = MAX_BG_BAKE_EDGE / float(edge)
    return max(1, int(round(ww * s))), max(1, int(round(hh * s))), 100.0 / s


def _expand_to_square_canvas(
    out: dict[str, Any],
    layers: list[Any],
) -> tuple[int, int]:
    """Pad non-square comps to max(w,h) and shift layers so art stays centered."""
    w = max(1, int(out.get("w") or 512))
    h = max(1, int(out.get("h") or 512))
    if w == h:
        return w, h
    side = max(w, h)
    pad_x = (side - w) / 2.0
    pad_y = (side - h) / 2.0
    out["w"] = side
    out["h"] = side
    for layer in layers:
        if not isinstance(layer, dict):
            continue
        ks = layer.get("ks")
        if not isinstance(ks, dict):
            continue
        p = ks.get("p")
        if not isinstance(p, dict) or int(p.get("a") or 0) != 0:
            continue
        k = p.get("k")
        if not isinstance(k, list) or len(k) < 2:
            continue
        try:
            k[0] = float(k[0]) + pad_x
            k[1] = float(k[1]) + pad_y
        except (TypeError, ValueError):
            continue
    return side, side


def _promote_existing_background_to_metallic(
    layers: list[Any],
    assets: list[Any],
) -> None:
    """Rename legacy template ``background`` → ``metallic_plate`` (Entelair copper).

    Skip when ``metallic_plate`` already exists, or when ``background`` is a prior
    claim bake (``arcoriClaimBg``), so re-bake stays idempotent for guardians.
    """
    has_metallic = any(
        isinstance(L, dict) and str(L.get("nm") or "") == _LAYER_METALLIC
        for L in layers
    )
    if has_metallic:
        return

    for layer in layers:
        if not isinstance(layer, dict):
            continue
        if str(layer.get("nm") or "") != _LAYER_BG:
            continue
        if layer.get("arcoriClaimBg"):
            return
        layer["nm"] = _LAYER_METALLIC
        ref = str(layer.get("refId") or "")
        if ref == _ASSET_ID:
            for asset in assets:
                if not isinstance(asset, dict):
                    continue
                if str(asset.get("id") or "") != _ASSET_ID:
                    continue
                metallic_id = "asset_metallic_plate"
                asset["id"] = metallic_id
                layer["refId"] = metallic_id
                break


def _upsert_background_asset(
    assets: list[Any],
    *,
    data_url: str,
    w: int,
    h: int,
) -> None:
    for asset in assets:
        if not isinstance(asset, dict):
            continue
        if str(asset.get("id") or "") == _ASSET_ID:
            asset["p"] = data_url
            asset["e"] = 1
            asset["w"] = w
            asset["h"] = h
            asset["u"] = ""
            return
    assets.append(
        {
            "id": _ASSET_ID,
            "w": w,
            "h": h,
            "u": "",
            "p": data_url,
            "e": 1,
        }
    )


def _upsert_background_layer(layers: list[Any], *, scale_pct: float) -> None:
    """Ensure a bottom-most ``background`` image layer (last in AE top-first list)."""
    # Remove any existing claim background layer (after metallic promote).
    kept = [
        L
        for L in layers
        if not (isinstance(L, dict) and str(L.get("nm") or "") == _LAYER_BG)
    ]
    layers[:] = kept

    max_ind = 0
    max_op = 30.0
    for layer in layers:
        if not isinstance(layer, dict):
            continue
        if isinstance(layer.get("ind"), int):
            max_ind = max(max_ind, int(layer["ind"]))
        if isinstance(layer.get("op"), (int, float)):
            max_op = max(max_op, float(layer["op"]))

    # Full-bleed like Entelair metallic_plate: top-left at origin.
    # scale_pct > 100 when asset was capped below composition size.
    bg_layer = {
        "ddd": 0,
        "ind": max_ind + 1,
        "ty": 2,
        "nm": _LAYER_BG,
        "refId": _ASSET_ID,
        "arcoriClaimBg": True,
        "sr": 1,
        "ks": {
            "o": {"a": 0, "k": 100},
            "r": {"a": 0, "k": 0},
            "p": {"a": 0, "k": [0, 0, 0]},
            "a": {"a": 0, "k": [0, 0, 0]},
            "s": {"a": 0, "k": [scale_pct, scale_pct, 100]},
        },
        "ao": 0,
        "ip": 0,
        "op": max_op,
        "st": 0,
        "bm": 0,
    }
    layers.append(bg_layer)


def _rasterize_background(
    background: dict[str, Any],
    *,
    w: int,
    h: int,
) -> str | None:
    """Return base64 PNG (no data: prefix) or None."""
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        if LOGGING_SWITCH:
            customlog("avari: kin bg bake needs Pillow")
        return None

    image_url = str(background.get("imageUrl") or "").strip()
    theme = str(background.get("theme") or "").strip().upper()

    if image_url:
        path = _resolve_background_image_path(image_url, background)
        if path is not None and path.is_file():
            try:
                src = Image.open(path).convert("RGBA")
                fitted = _cover_resize(src, w, h)
                return _png_b64(fitted)
            except OSError as exc:
                if LOGGING_SWITCH:
                    customlog(f"avari: kin bg image read fail {path}: {exc}")

    color_a = _parse_hex(str(background.get("colorHex") or "#2A2A2E"))
    if theme == "GRADIENT":
        color_b = _parse_hex(
            str(background.get("colorHexB") or background.get("colorHex") or "#2A2A2E")
        )
        angle = float(background.get("angleDegrees") or 180.0)
        img = _gradient_image(w, h, color_a, color_b, angle)
        return _png_b64(img)

    # SOLID (default) and unknown themes with colorHex
    img = Image.new("RGBA", (w, h), color_a)
    return _png_b64(img)


def _resolve_background_image_path(
    image_url: str,
    background: dict[str, Any],
) -> Path | None:
    from modules.avari.kin_backgrounds import backgrounds_dir, kin_media_root

    file_name = str(background.get("fileName") or "").strip()
    if file_name:
        candidate = backgrounds_dir() / file_name
        if candidate.is_file():
            return candidate

    # /catalog-media/kin/ser001/00backgrounds/FOO.webp → under kin media root
    url = image_url.split("?", 1)[0]
    marker = "/catalog-media/kin/"
    if marker in url:
        rel = url.split(marker, 1)[1]
        candidate = kin_media_root() / rel
        if candidate.is_file():
            return candidate

    # Absolute path fallback (tests)
    if os.path.isfile(image_url):
        return Path(image_url)
    return None


def _cover_resize(src: Any, w: int, h: int) -> Any:
    from PIL import Image

    sw, sh = src.size
    scale = max(w / max(sw, 1), h / max(sh, 1))
    nw, nh = max(1, int(sw * scale)), max(1, int(sh * scale))
    resized = src.resize((nw, nh), Image.Resampling.LANCZOS)
    left = max(0, (nw - w) // 2)
    top = max(0, (nh - h) // 2)
    return resized.crop((left, top, left + w, top + h))


def _gradient_image(
    w: int,
    h: int,
    color_a: tuple[int, int, int, int],
    color_b: tuple[int, int, int, int],
    angle_degrees: float,
) -> Any:
    from PIL import Image
    import numpy as np

    # Angle: 180 default = top→bottom in Kin UI (begin topCenter → end bottomCenter).
    rad = math.radians(angle_degrees)
    # Direction vector for gradient (matches Flutter kinBackgroundGradientAlignments).
    dx, dy = math.sin(rad), -math.cos(rad)
    ys, xs = np.mgrid[0:h, 0:w]
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0
    proj = (xs - cx) * dx + (ys - cy) * dy
    pmin, pmax = float(proj.min()), float(proj.max())
    t = (proj - pmin) / (pmax - pmin + 1e-9)
    t = t[..., None]
    a = np.array(color_a, dtype=np.float64)
    b = np.array(color_b, dtype=np.float64)
    rgba = (a * (1.0 - t) + b * t).astype(np.uint8)
    return Image.fromarray(rgba, mode="RGBA")


def _parse_hex(raw: str) -> tuple[int, int, int, int]:
    s = (raw or "").strip().lstrip("#")
    if len(s) == 6:
        s = "FF" + s
    if len(s) != 8:
        return (42, 42, 46, 255)
    try:
        v = int(s, 16)
    except ValueError:
        return (42, 42, 46, 255)
    return ((v >> 16) & 255, (v >> 8) & 255, v & 255, (v >> 24) & 255)


def _png_b64(img: Any) -> str:
    from modules.avari.kin_lottie_optimize import encode_image_bytes

    # Encode at full composition size as WebP; claim bake uniform-scales afterward.
    raw = encode_image_bytes(img, max_edge=None, format="WEBP")
    return base64.b64encode(raw).decode("ascii")
