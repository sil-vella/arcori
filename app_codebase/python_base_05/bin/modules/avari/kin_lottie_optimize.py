"""Resize Kin Lottie payloads with a **single uniform scale** (layout-safe).

Inline image assets are re-encoded as **WebP** (alpha-preserving) for claim /
disc face size. Lottie allows ``data:image/webp;base64,…``; Flutter ``lottie``
loads them via ``MemoryImage`` / platform codecs.
"""

from __future__ import annotations

import base64
import io
from typing import Any

from core.utils.dev_logger import customlog

LOGGING_SWITCH = True

# Claim / disc faces: one scale for canvas + every inline image + anchors/positions.
# Catalog templates are authored ≤384; keep claim cap aligned.
MAX_COMP_EDGE = 384

# Legacy helper max edge (do not use on full-canvas embeds/BG independently).
MAX_ASSET_EDGE = 384

# Lossy WebP with alpha — much smaller than PNG at disc sizes.
# method=4 is a speed/size compromise (6 is very slow on multi‑MB templates).
WEBP_QUALITY = 82
WEBP_METHOD = 4

_PNG_PREFIX = "data:image/png;base64,"
_WEBP_PREFIX = "data:image/webp;base64,"
_JPEG_PREFIXES = (
    "data:image/jpeg;base64,",
    "data:image/jpg;base64,",
)


def optimize_lottie_payload(
    lottie: dict[str, Any],
    *,
    max_comp_edge: int = MAX_COMP_EDGE,
    max_asset_edge: int | None = None,
) -> dict[str, Any]:
    """Uniformly scale composition + inline images; re-encode assets as WebP."""
    del max_asset_edge  # noqa: F841 — compat only
    if not isinstance(lottie, dict):
        return lottie
    out = dict(lottie)
    assets = list(out.get("assets") or [])
    layers = list(out.get("layers") or [])
    out["assets"] = assets
    out["layers"] = layers

    scale = _uniform_scale_factor(out, max_edge=max_comp_edge)
    if scale < 1.0 - 1e-9:
        _apply_uniform_scale(out, assets, layers, scale=scale)
        if LOGGING_SWITCH:
            customlog(
                f"avari: kin uniform scale {scale:.4f} → "
                f"{out.get('w')}x{out.get('h')} (webp)"
            )
    else:
        _reencode_inline_images(assets)

    return out


def encode_image_bytes(
    img: Any,
    *,
    max_edge: int | None = None,
    format: str = "WEBP",
) -> bytes:
    """Encode a Pillow image (optional max-edge fit). Default: WebP."""
    if max_edge is not None and max_edge > 0:
        img = _fit_max_edge(img, max_edge)
    fmt = (format or "WEBP").strip().upper()
    buf = io.BytesIO()
    if fmt == "PNG":
        img.save(buf, format="PNG", optimize=True)
    elif fmt in ("JPEG", "JPG"):
        img.convert("RGB").save(buf, format="JPEG", quality=WEBP_QUALITY, optimize=True)
    else:
        # Preserve alpha; quality applies to lossy WebP.
        img.save(
            buf,
            format="WEBP",
            quality=WEBP_QUALITY,
            method=WEBP_METHOD,
        )
    return buf.getvalue()


def encode_png_bytes(img: Any, *, max_edge: int | None = None) -> bytes:
    """PNG-encode (compat). Prefer [encode_image_bytes] / WebP for claim faces."""
    return encode_image_bytes(img, max_edge=max_edge, format="PNG")


def image_data_url(
    img: Any,
    *,
    max_edge: int | None = None,
    format: str = "WEBP",
) -> str:
    raw = encode_image_bytes(img, max_edge=max_edge, format=format)
    fmt = (format or "WEBP").strip().upper()
    if fmt == "PNG":
        prefix = _PNG_PREFIX
    elif fmt in ("JPEG", "JPG"):
        prefix = "data:image/jpeg;base64,"
    else:
        prefix = _WEBP_PREFIX
    return f"{prefix}{base64.b64encode(raw).decode('ascii')}"


def png_data_url(img: Any, *, max_edge: int | None = MAX_ASSET_EDGE) -> str:
    """Compat alias — now emits WebP (callers used this for claim BG embeds)."""
    return image_data_url(img, max_edge=max_edge, format="WEBP")


def webp_data_url(img: Any, *, max_edge: int | None = None) -> str:
    return image_data_url(img, max_edge=max_edge, format="WEBP")


def shrink_png_bytes(raw: bytes, *, max_edge: int = MAX_ASSET_EDGE) -> bytes:
    """Decode any raster → fit max edge → WebP bytes (name kept for callers)."""
    img = decode_image_bytes(raw)
    if img is None:
        return raw
    return encode_image_bytes(img, max_edge=max_edge, format="WEBP")


def decode_image_bytes(raw: bytes) -> Any | None:
    try:
        from PIL import Image
    except ImportError:
        return None
    try:
        return Image.open(io.BytesIO(raw)).convert("RGBA")
    except OSError:
        return None


def decode_data_url(data_url: str) -> tuple[Any, str] | None:
    """Return (RGBA image, mime subtype) or None."""
    if not isinstance(data_url, str) or not data_url.startswith("data:image/"):
        return None
    try:
        header, b64 = data_url.split(",", 1)
    except ValueError:
        return None
    mime = "png"
    if "image/webp" in header:
        mime = "webp"
    elif "image/jpeg" in header or "image/jpg" in header:
        mime = "jpeg"
    try:
        raw = base64.b64decode(b64, validate=False)
    except Exception:
        return None
    img = decode_image_bytes(raw)
    if img is None:
        return None
    return img, mime


def _fit_max_edge(img: Any, max_edge: int) -> Any:
    from PIL import Image

    w, h = img.size
    edge = max(w, h)
    if edge <= max_edge or edge < 1:
        return img
    scale = max_edge / float(edge)
    nw = max(1, int(round(w * scale)))
    nh = max(1, int(round(h * scale)))
    return img.resize((nw, nh), Image.Resampling.LANCZOS)


def _uniform_scale_factor(out: dict[str, Any], *, max_edge: int) -> float:
    w = max(1, int(out.get("w") or 512))
    h = max(1, int(out.get("h") or 512))
    side = max(w, h)
    if side <= max_edge:
        return 1.0
    return max_edge / float(side)


def _apply_uniform_scale(
    out: dict[str, Any],
    assets: list[Any],
    layers: list[Any],
    *,
    scale: float,
) -> None:
    w = max(1, int(out.get("w") or 512))
    h = max(1, int(out.get("h") or 512))
    out["w"] = max(1, int(round(w * scale)))
    out["h"] = max(1, int(round(h * scale)))

    _scale_layers_geometry(layers, scale=scale)

    # Precomp assets carry nested layers (masks / transforms) in local space.
    for asset in assets:
        if not isinstance(asset, dict):
            continue
        nested = asset.get("layers")
        if isinstance(nested, list):
            _scale_layers_geometry(nested, scale=scale)
        aw = asset.get("w")
        ah = asset.get("h")
        if isinstance(aw, (int, float)) and isinstance(ah, (int, float)):
            # Non-image precomp size (image assets overwritten after resize).
            if not (
                isinstance(asset.get("p"), str)
                and _is_inline_image_data_url(str(asset.get("p")))
            ):
                asset["w"] = max(1, int(round(float(aw) * scale)))
                asset["h"] = max(1, int(round(float(ah) * scale)))

    _resize_inline_images(assets, scale=scale)


def _scale_layers_geometry(layers: list[Any], *, scale: float) -> None:
    for layer in layers:
        if not isinstance(layer, dict):
            continue
        ks = layer.get("ks")
        if isinstance(ks, dict):
            for key in ("p", "a"):
                _scale_vec_node(ks.get(key), scale)
        masks = layer.get("masksProperties")
        if isinstance(masks, list):
            for mask in masks:
                if isinstance(mask, dict):
                    _scale_mask(mask, scale)


def _scale_vec_node(node: Any, scale: float) -> None:
    if not isinstance(node, dict) or int(node.get("a") or 0) != 0:
        return
    k = node.get("k")
    if not isinstance(k, list) or len(k) < 2:
        return
    try:
        k[0] = float(k[0]) * scale
        k[1] = float(k[1]) * scale
    except (TypeError, ValueError):
        return


def _scale_mask(mask: dict[str, Any], scale: float) -> None:
    """Scale layer mask path (Entelair eyes — unscaled masks cut irises)."""
    pt = mask.get("pt")
    if not isinstance(pt, dict):
        return
    if int(pt.get("a") or 0) == 0:
        _scale_bezier_shape(pt.get("k"), scale)
        return
    # Animated mask: scale each keyframe's shape payload.
    k = pt.get("k")
    if not isinstance(k, list):
        return
    for frame in k:
        if not isinstance(frame, dict):
            continue
        for key in ("s", "e"):
            shapes = frame.get(key)
            if isinstance(shapes, list):
                for shape in shapes:
                    _scale_bezier_shape(shape, scale)


def _scale_bezier_shape(shape: Any, scale: float) -> None:
    if not isinstance(shape, dict):
        return
    for key in ("v", "i", "o"):
        pts = shape.get(key)
        if not isinstance(pts, list):
            continue
        for pt in pts:
            if not isinstance(pt, list) or len(pt) < 2:
                continue
            try:
                pt[0] = float(pt[0]) * scale
                pt[1] = float(pt[1]) * scale
            except (TypeError, ValueError):
                continue


def _is_inline_image_data_url(p: str) -> bool:
    return (
        p.startswith(_PNG_PREFIX)
        or p.startswith(_WEBP_PREFIX)
        or any(p.startswith(x) for x in _JPEG_PREFIXES)
        or p.startswith("data:image/")
    )


def _resize_inline_images(assets: list[Any], *, scale: float) -> None:
    try:
        from PIL import Image
    except ImportError:
        if LOGGING_SWITCH:
            customlog("avari: kin optimize needs Pillow")
        return

    for asset in assets:
        if not isinstance(asset, dict):
            continue
        p = asset.get("p")
        if not isinstance(p, str) or not _is_inline_image_data_url(p):
            continue
        decoded = decode_data_url(p)
        if decoded is None:
            continue
        img, _mime = decoded
        ow, oh = img.size
        nw = max(1, int(round(ow * scale)))
        nh = max(1, int(round(oh * scale)))
        if (nw, nh) != (ow, oh):
            img = img.resize((nw, nh), Image.Resampling.LANCZOS)
        asset["p"] = webp_data_url(img, max_edge=None)
        asset["w"] = nw
        asset["h"] = nh
        asset["e"] = 1


def _reencode_inline_images(assets: list[Any]) -> None:
    for asset in assets:
        if not isinstance(asset, dict):
            continue
        p = asset.get("p")
        if not isinstance(p, str) or not _is_inline_image_data_url(p):
            continue
        decoded = decode_data_url(p)
        if decoded is None:
            continue
        img, _mime = decoded
        asset["p"] = webp_data_url(img, max_edge=None)
        asset["w"] = img.size[0]
        asset["h"] = img.size[1]
        asset["e"] = 1


# Back-compat aliases used by older call sites / tests.
_resize_inline_pngs = _resize_inline_images
_reencode_inline_pngs = _reencode_inline_images
