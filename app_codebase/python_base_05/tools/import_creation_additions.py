#!/usr/bin/env python3
"""Convert Creation PNGs in 000_creation/{theme}/ to webp and append SER000 JSON."""

from __future__ import annotations

import json
import shutil
from pathlib import Path

from PIL import Image

from import_foundations_series import (
    REGION_NAME_TO_CODE,
    design_family,
    load_region_rels,
)

REPO = Path(__file__).resolve().parents[3]
ART_ROOT = REPO / "assets" / "images" / "arcori" / "000_creation"
SERIES_JSON = (
    REPO
    / "app_codebase"
    / "python_base_05"
    / "bin"
    / "modules"
    / "catalog"
    / "data"
    / "series"
    / "creation"
)
ADDITIONS = REPO / "assets" / "images" / "arcori" / "additions"

ID_TOKEN = "SER000"
LEGACY = {"preservationRequirement": 50, "closureMilestone": 100}
WEIGHT = 0.01
SERIES_DISPLAY = "Creation Series"

# (theme_dir, theme, theme_code, name, design_code, region, style, finish, color, seq)
DESIGNS: list[tuple[str, str, str, str, str, str, str, str, str, int]] = [
    (
        "the_light",
        "The Light",
        "LGT",
        "Ivory Gatewalker",
        "IGW",
        "Everlight Grove",
        "Realistic",
        "Standard",
        "#E6DCC8",
        2,
    ),
    (
        "the_dark",
        "The Dark",
        "DRK",
        "Eclipse Veilwalker",
        "EVW",
        "Ashdrift Hill",
        "Realistic",
        "Standard",
        "#1A1A1C",
        2,
    ),
]


def find_png(theme_dir: str) -> Path:
    folder = ART_ROOT / theme_dir
    matches = [p for p in folder.glob("*.png") if p.is_file()]
    if len(matches) != 1:
        raise FileNotFoundError(f"Expected 1 png in {folder}, got {matches}")
    return matches[0]


def png_to_webp(src: Path, dest: Path) -> None:
    im = Image.open(src)
    if im.mode not in {"RGB", "RGBA"}:
        im = im.convert("RGB")
    elif im.mode == "RGBA":
        bg = Image.new("RGB", im.size, (0, 0, 0))
        bg.paste(im, mask=im.split()[-1])
        im = bg
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        dest.unlink()
    im.save(dest, format="WEBP", quality=90, method=6)


def build_design(
    *,
    theme: str,
    theme_code: str,
    name: str,
    code: str,
    region_name: str,
    style: str,
    finish: str,
    color: str,
    seq: int,
    region_rels: dict[str, tuple[list[str], list[str]]],
) -> tuple[dict, str]:
    if region_name not in REGION_NAME_TO_CODE:
        raise SystemExit(f"Invalid region {region_name!r} for {name!r}")
    if region_name.lower() == "velora":
        raise SystemExit(f"Velora is not a region: {name!r}")
    region_code = REGION_NAME_TO_CODE[region_name]
    affinity, hostility = region_rels.get(region_code, ([], []))
    art_stem = f"{theme_code}-{code}-{ID_TOKEN}-{seq:04d}"
    internal_id = f"{theme_code}-{code}-{ID_TOKEN}-GEN001-{seq:04d}"
    prompt = (
        f"Give me an image with {name} in {style.lower()} style with a "
        f"{finish.lower()} finish and no effect. Use a background that is "
        f"visually related to {name}. No borders, no frames. The subject should "
        f"be horizontally and vertically centered. The subject should fill around "
        f"2/4 of the total image size. The image must use a 1:1 aspect ratio in "
        f"webp format and named {internal_id}.webp"
    )
    design = {
        "internalId": internal_id,
        "themeCode": theme_code,
        "designCode": code,
        "designFamily": design_family(name),
        "design": name,
        "inspiration": None,
        "location": {
            "regionCode": region_code,
            "locationCode": None,
            "latitude": None,
            "longitude": None,
            "radiusMeters": None,
        },
        "affinity": affinity,
        "hostility": hostility,
        "generation": {
            "roman": "I",
            "number": 1,
            "creator": {"type": "system", "playerId": None},
        },
        "type": "arcori",
        "theme": theme,
        "subtheme": theme,
        "style": style,
        "finish": finish,
        "color": color,
        "effect": "None",
        "selectionWeight": WEIGHT,
        "series": SERIES_DISPLAY,
        "worldState": "Active",
        "seasonState": "Active",
        "artworkPrompt": prompt,
        "loreDescription": (
            f"A collectible {name} Arcori generation I from the {SERIES_DISPLAY}, "
            f"bound to {region_name}."
        ),
        "legacy": dict(LEGACY),
    }
    return design, art_stem


def main() -> None:
    region_rels = load_region_rels()
    archive = ADDITIONS / "_imported_creation"
    archive.mkdir(parents=True, exist_ok=True)

    for (
        theme_dir,
        theme,
        theme_code,
        name,
        code,
        region,
        style,
        finish,
        color,
        seq,
    ) in DESIGNS:
        json_path = SERIES_JSON / f"{theme_dir}.json"
        doc = json.loads(json_path.read_text(encoding="utf-8"))
        designs = list(doc.get("designs") or [])
        used_codes = {str(d.get("designCode") or "") for d in designs}
        used_names = {str(d.get("design") or "") for d in designs}
        if code in used_codes:
            raise SystemExit(f"designCode {code} already used in {theme}")
        if name in used_names:
            raise SystemExit(f"design {name!r} already present in {theme}")

        design, art_stem = build_design(
            theme=theme,
            theme_code=theme_code,
            name=name,
            code=code,
            region_name=region,
            style=style,
            finish=finish,
            color=color,
            seq=seq,
            region_rels=region_rels,
        )
        png = find_png(theme_dir)
        dest = ART_ROOT / theme_dir / f"{art_stem}.webp"
        png_to_webp(png, dest)
        print(f"webp {png.name} -> {dest.relative_to(ART_ROOT.parent)}")

        archived = archive / png.name
        if archived.exists():
            archived.unlink()
        shutil.move(str(png), str(archived))
        print(f"archived {png.name}")

        designs.append(design)
        designs.sort(key=lambda d: int(str(d["internalId"]).rsplit("-", 1)[-1]))
        doc["designs"] = designs
        json_path.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
        print(f"json {json_path.relative_to(REPO)} ({len(designs)} designs)")

    total = 0
    for path in SERIES_JSON.glob("*.json"):
        doc = json.loads(path.read_text(encoding="utf-8"))
        for d in doc.get("designs") or []:
            total += 1
            region = (d.get("location") or {}).get("regionCode")
            if region in {None, "", "VEL", "VLR"}:
                raise SystemExit(f"Bad region on {d.get('internalId')}: {region}")
            if float(d.get("selectionWeight") or 0) != WEIGHT:
                raise SystemExit(f"Creation weight must be {WEIGHT}: {d.get('internalId')}")
    if total != 4:
        raise SystemExit(f"Expected 4 creation designs, got {total}")
    print(f"ok {total} creation designs")


if __name__ == "__main__":
    main()
