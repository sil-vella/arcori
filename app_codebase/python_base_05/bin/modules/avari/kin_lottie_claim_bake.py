"""Build claimed Kin Lottie on the server.

Human claims: client sends already-baked preview Lottie (multipart gzip) for
embeds + part styles (client SSOT). Background is always re-baked here from the
claim ``background`` payload (disk/Pillow) — tall Entelair templates (ASP/HGD)
often OOM on-device when rasterizing image BGs after the heavy template is
already in memory, leaving solid gray ``#2A2A2E``.

AI feed / tools without a client Lottie: load catalog template and bake embeds /
part styles / background here (full server SSOT).
"""

from __future__ import annotations

import colorsys
import copy
import json
from pathlib import Path
from typing import Any

from core.utils.dev_logger import customlog
from modules.avari.kin_backgrounds import kin_media_root
from modules.avari.kin_embeds import embeds_dir, list_kin_embeds
from modules.avari.kin_lottie_background import bake_claim_background_into_lottie
from modules.avari.kin_lottie_optimize import (
    decode_data_url,
    decode_image_bytes,
    optimize_lottie_payload,
    webp_data_url,
)

LOGGING_SWITCH = True

_CUS_EMBED = "CUS-0006"

def build_claim_lottie(
    *,
    kin_serial: str,
    applied: list[Any] | None,
    background: dict[str, Any] | None,
    lottie_override: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Claim face Lottie: client embeds/styles SSOT; server always owns BG bake.

    Re-baking embeds/styles on top of client JSON caused Entelair square-pad +
    style re-encode drift (cut eyes, missing arms). Background is different:
    server reads catalog images from disk and is reliable for tall canvases.
    """
    if isinstance(lottie_override, dict) and lottie_override:
        out = copy.deepcopy(lottie_override)
        if isinstance(background, dict) and background:
            out = bake_claim_background_into_lottie(out, background)
            if LOGGING_SWITCH:
                customlog(
                    f"avari: kin claim client-lottie SSOT serial={kin_serial} "
                    f"→ rebake background + optimize"
                )
        elif LOGGING_SWITCH:
            customlog(
                f"avari: kin claim client-lottie SSOT serial={kin_serial} "
                f"→ optimize only"
            )
        return optimize_lottie_payload(out)

    base = load_template_lottie(kin_serial)
    applied_list = applied if isinstance(applied, list) else []
    base = bake_embeds_into_lottie(base, kin_serial=kin_serial, applied=applied_list)
    base = apply_part_styles_from_applied(base, kin_serial=kin_serial, applied=applied_list)
    if isinstance(background, dict) and background:
        base = bake_claim_background_into_lottie(base, background)
    return optimize_lottie_payload(base)


def load_template_lottie(kin_serial: str) -> dict[str, Any]:
    serial = (kin_serial or "").strip()
    if not serial:
        raise FileNotFoundError("kinSerial required to load template Lottie")
    path = find_template_lottie_path(serial)
    if path is None:
        raise FileNotFoundError(f"template Lottie not found for {serial}")
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"template Lottie is not an object: {path}")
    if LOGGING_SWITCH:
        customlog(f"avari: kin claim template loaded serial={serial} path={path}")
    return copy.deepcopy(data)


def find_template_lottie_path(kin_serial: str) -> Path | None:
    root = kin_media_root() / "ser001"
    if not root.is_dir():
        return None
    name = f"{kin_serial}.json"
    matches = sorted(p for p in root.rglob(name) if p.is_file())
    # Prefer type folders over 00* catalog dirs.
    preferred = [
        p
        for p in matches
        if "00embeds" not in p.parts and "00backgrounds" not in p.parts
    ]
    pool = preferred or matches
    return pool[0] if pool else None


def bake_embeds_into_lottie(
    lottie: dict[str, Any],
    *,
    kin_serial: str,
    applied: list[Any],
) -> dict[str, Any]:
    selection = _embed_selection_from_applied(applied)
    if not selection:
        return lottie

    catalog = list_kin_embeds().get("embeds") or []
    by_serial = {
        str(row.get("serial") or ""): row
        for row in catalog
        if isinstance(row, dict) and str(row.get("serial") or "")
    }

    out = dict(lottie)
    assets = list(out.get("assets") or [])
    layers = list(out.get("layers") or [])
    out["assets"] = assets
    out["layers"] = layers
    comp_w = max(1, int(out.get("w") or 512))
    comp_h = max(1, int(out.get("h") or 512))

    for embed_serial, tint in selection.items():
        row = by_serial.get(embed_serial)
        if row is None:
            continue
        placement, part_ok = _placement_for_kin(row, kin_serial)
        if placement is None or not part_ok:
            if LOGGING_SWITCH:
                customlog(
                    f"avari: kin embed skip {embed_serial} — no placement for {kin_serial}"
                )
            continue
        png_path = _embed_png_path(row)
        if png_path is None or not png_path.is_file():
            continue
        try:
            raw = png_path.read_bytes()
        except OSError:
            continue
        # Keep full authored canvas (transparent padding = position). Do not
        # independently downscale — final uniform optimize scales everything.
        raw = _tint_png_bytes(
            raw,
            hue=float(tint.get("hue") or 0),
            light_dark=float(tint.get("lightDark") or 0),
        )
        _upsert_embed_layer(
            assets=assets,
            layers=layers,
            embed_serial=embed_serial,
            png_bytes=raw,
            placement=placement,
            comp_w=comp_w,
            comp_h=comp_h,
        )
    return out


def apply_part_styles_from_applied(
    lottie: dict[str, Any],
    *,
    kin_serial: str,
    applied: list[Any],
) -> dict[str, Any]:
    """Tint part image assets from hue/sat/lightDark/color customs (best-effort)."""
    kin = _kin_row(kin_serial)
    customs = _customs_by_serial()
    if kin is None or not customs:
        return lottie

    by_part: dict[str, dict[str, Any]] = {}
    for row in applied:
        if not isinstance(row, dict):
            continue
        part = str(row.get("partSerial") or "").strip()
        custom = str(row.get("customSerial") or "").strip()
        if not part or not custom or custom == _CUS_EMBED:
            continue
        by_part.setdefault(part, {})[custom] = row.get("value")

    styles_by_layer: dict[str, dict[str, float | str | None]] = {}
    for part in kin.get("parts") or []:
        if not isinstance(part, dict):
            continue
        part_serial = str(part.get("serial") or "")
        values = by_part.get(part_serial)
        if not values:
            continue
        hue = 0.0
        sat = 1.0
        light = 0.0
        replace: str | None = None
        for cserial, value in values.items():
            meta = customs.get(cserial) or {}
            ctype = str(meta.get("customType") or "")
            if ctype == "hue" and isinstance(value, (int, float)):
                hue = float(value)
            elif ctype == "saturation" and isinstance(value, (int, float)):
                sat = float(value)
            elif ctype == "lightDark" and isinstance(value, (int, float)):
                light = float(value)
            elif ctype == "color" and value is not None:
                replace = str(value)
        if (
            abs(hue) < 0.01
            and abs(sat - 1.0) < 0.01
            and abs(light) < 0.01
            and not replace
        ):
            continue
        layer_names = list(part.get("affectsLayers") or [])
        layer_name = str(part.get("layerName") or "")
        if not layer_names and layer_name:
            layer_names = [layer_name]
        for nm in layer_names:
            if not nm:
                continue
            styles_by_layer[str(nm)] = {
                "hue": hue,
                "sat": sat,
                "light": light,
                "replace": replace,
            }

    if not styles_by_layer:
        return lottie

    out = dict(lottie)
    assets = list(out.get("assets") or [])
    layers = list(out.get("layers") or [])
    out["assets"] = assets
    out["layers"] = layers
    assets_by_id = {
        str(a.get("id") or ""): a for a in assets if isinstance(a, dict)
    }

    for layer in layers:
        if not isinstance(layer, dict):
            continue
        nm = str(layer.get("nm") or "")
        style = styles_by_layer.get(nm)
        if style is None:
            continue
        ref = str(layer.get("refId") or "")
        asset = assets_by_id.get(ref)
        if asset is None:
            continue
        p = asset.get("p")
        if not isinstance(p, str):
            continue
        decoded = decode_data_url(p)
        if decoded is None:
            continue
        img, _mime = decoded
        import io

        buf = io.BytesIO()
        img.save(buf, format="PNG")
        tinted = _tint_png_bytes(
            buf.getvalue(),
            hue=float(style["hue"] or 0),
            saturation=float(style["sat"] or 1),
            light_dark=float(style["light"] or 0),
            replace_hex=style.get("replace") if isinstance(style.get("replace"), str) else None,
        )
        restored = decode_image_bytes(tinted)
        if restored is None:
            continue
        # Keep pixel size; final optimize may scale; WebP for size.
        asset["p"] = webp_data_url(restored, max_edge=None)
    return out


def _embed_selection_from_applied(applied: list[Any]) -> dict[str, dict[str, float]]:
    out: dict[str, dict[str, float]] = {}
    for row in applied:
        if not isinstance(row, dict):
            continue
        if str(row.get("customSerial") or "") != _CUS_EMBED:
            continue
        value = row.get("value")
        if isinstance(value, str) and value.strip():
            out[value.strip()] = {"hue": 0.0, "lightDark": 0.0}
        elif isinstance(value, list):
            for item in value:
                s = str(item or "").strip()
                if s:
                    out[s] = {"hue": 0.0, "lightDark": 0.0}
        elif isinstance(value, dict):
            for key, tint in value.items():
                s = str(key or "").strip()
                if not s:
                    continue
                hue = 0.0
                ld = 0.0
                if isinstance(tint, dict):
                    if isinstance(tint.get("hue"), (int, float)):
                        hue = float(tint["hue"])
                    if isinstance(tint.get("lightDark"), (int, float)):
                        ld = float(tint["lightDark"])
                out[s] = {"hue": hue, "lightDark": ld}
    return out


def _placement_for_kin(
    row: dict[str, Any], kin_serial: str
) -> tuple[dict[str, Any] | None, bool]:
    atts = row.get("attachments")
    if not isinstance(atts, list):
        return None, False
    for att in atts:
        if not isinstance(att, dict):
            continue
        if str(att.get("kinSerial") or "") != kin_serial:
            continue
        placement = att.get("placement")
        if isinstance(placement, dict):
            return placement, True
    return None, False


def _embed_png_path(row: dict[str, Any]) -> Path | None:
    file_name = str(row.get("fileName") or "").strip().lstrip("/")
    if not file_name or ".." in file_name.split("/"):
        # Derive from imageUrl when fileName omitted.
        image_url = str(row.get("imageUrl") or "")
        marker = "/00embeds/"
        if marker in image_url:
            file_name = image_url.split(marker, 1)[1]
        else:
            return None
    return embeds_dir() / file_name


def _upsert_embed_layer(
    *,
    assets: list[Any],
    layers: list[Any],
    embed_serial: str,
    png_bytes: bytes,
    placement: dict[str, Any],
    comp_w: int,
    comp_h: int,
) -> None:
    from PIL import Image
    import io

    layer_name = f"embed_{embed_serial}"
    asset_id = f"asset_embed_{embed_serial}"
    try:
        img = Image.open(io.BytesIO(png_bytes)).convert("RGBA")
    except OSError:
        return
    img_w, img_h = img.size
    # WebP data URL — Flutter lottie MemoryImage decodes WebP fine.
    data_url = webp_data_url(img, max_edge=None)

    assets[:] = [a for a in assets if not (isinstance(a, dict) and a.get("id") == asset_id)]
    assets.append(
        {"id": asset_id, "w": img_w, "h": img_h, "u": "", "p": data_url, "e": 1}
    )

    layers[:] = [
        L for L in layers if not (isinstance(L, dict) and L.get("nm") == layer_name)
    ]

    in_front = str(placement.get("inFrontOf") or "").strip()
    behind = str(placement.get("behindLayer") or "").strip()
    target = in_front or behind
    if not target:
        return
    target_idx = next(
        (
            i
            for i, L in enumerate(layers)
            if isinstance(L, dict) and str(L.get("nm") or "") == target
        ),
        -1,
    )
    if target_idx < 0:
        return

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

    pos = placement.get("p")
    if not (isinstance(pos, list) and len(pos) >= 2):
        # Full-canvas addition art stacks at origin (same w×h as template).
        pos = [0.0, 0.0, 0.0]
    scale = placement.get("s")
    if not (isinstance(scale, list) and len(scale) >= 2):
        scale = [100.0, 100.0, 100.0]

    layer = {
        "ddd": 0,
        "ind": max_ind + 1,
        "ty": 2,
        "nm": layer_name,
        "refId": asset_id,
        "sr": 1,
        "ks": {
            "o": {"a": 0, "k": 100},
            "r": {"a": 0, "k": 0},
            "p": {"a": 0, "k": [float(pos[0]), float(pos[1]), float(pos[2] if len(pos) > 2 else 0)]},
            "a": {"a": 0, "k": [0.0, 0.0, 0.0]},
            "s": {
                "a": 0,
                "k": [
                    float(scale[0]),
                    float(scale[1]),
                    float(scale[2] if len(scale) > 2 else 100),
                ],
            },
        },
        "ao": 0,
        "ip": 0,
        "op": max_op,
        "st": 0,
        "bm": 0,
    }
    insert_at = target_idx if in_front else target_idx + 1
    layers.insert(insert_at, layer)


def _tint_png_bytes(
    raw: bytes,
    *,
    hue: float = 0.0,
    saturation: float = 1.0,
    light_dark: float = 0.0,
    replace_hex: str | None = None,
) -> bytes:
    if (
        abs(hue) < 0.01
        and abs(saturation - 1.0) < 0.01
        and abs(light_dark) < 0.01
        and not replace_hex
    ):
        return raw
    try:
        from PIL import Image
        import io
    except ImportError:
        return raw
    try:
        img = Image.open(io.BytesIO(raw)).convert("RGBA")
    except OSError:
        return raw

    replace = _parse_hex_rgb(replace_hex) if replace_hex else None
    pixels = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            if replace is not None:
                rr, gg, bb = replace
                pixels[x, y] = (
                    int(r * rr / 255),
                    int(g * gg / 255),
                    int(b * bb / 255),
                    a,
                )
                continue
            rf, gf, bf = r / 255.0, g / 255.0, b / 255.0
            h1, s1, v1 = colorsys.rgb_to_hsv(rf, gf, bf)
            h2 = (h1 + (hue / 360.0)) % 1.0
            s2 = max(0.0, min(1.0, s1 * saturation))
            v2 = max(0.0, min(1.0, v1 + light_dark))
            nr, ng, nb = colorsys.hsv_to_rgb(h2, s2, v2)
            pixels[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)

    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def _parse_hex_rgb(raw: str | None) -> tuple[int, int, int] | None:
    if not raw:
        return None
    s = raw.strip().lstrip("#")
    if len(s) == 8:
        s = s[2:]
    if len(s) != 6:
        return None
    try:
        v = int(s, 16)
    except ValueError:
        return None
    return ((v >> 16) & 255, (v >> 8) & 255, v & 255)


def _kin_row(kin_serial: str) -> dict[str, Any] | None:
    path = kin_media_root() / "ser001" / "kins.json"
    if not path.is_file():
        # Fallback: flutter-bundled path not on VPS — try repo-relative via env.
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    rows = data.get("kins") if isinstance(data, dict) else None
    if not isinstance(rows, list):
        return None
    for row in rows:
        if isinstance(row, dict) and str(row.get("serial") or "") == kin_serial:
            return row
    return None


def _customs_by_serial() -> dict[str, dict[str, Any]]:
    path = kin_media_root() / "ser001" / "customs.json"
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    rows = data.get("customs") if isinstance(data, dict) else None
    if not isinstance(rows, list):
        return {}
    out: dict[str, dict[str, Any]] = {}
    for row in rows:
        if not isinstance(row, dict):
            continue
        serial = str(row.get("serial") or "")
        if serial:
            out[serial] = row
    return out
