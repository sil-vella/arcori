#!/usr/bin/env python3
"""Import Foundations art from assets/images/arcori/additions → seq 0004+."""

from __future__ import annotations

import hashlib
import json
import re
import shutil
from pathlib import Path

from import_foundations_series import (
    ART_ROOT,
    COLOR,
    ID_TOKEN,
    LEGACY,
    REGION_NAME_TO_CODE,
    SERIES_DISPLAY,
    SERIES_JSON,
    SERIES_KEY,
    THEME_CODES,
    design_code,
    design_family,
    load_region_rels,
)

REPO = Path(__file__).resolve().parents[3]
ADDITIONS = REPO / "assets" / "images" / "arcori" / "additions"

SEQ = 4  # next slot per theme (existing 0001–0003)


def weight_for(internal_id: str) -> float:
    """Deterministic selectionWeight in [3.0, 10.0] step 0.1."""
    n = int(hashlib.md5(internal_id.encode("utf-8")).hexdigest()[:8], 16) % 71
    return round(3.0 + n * 0.1, 1)


def parse_manifests() -> list[tuple[int, str, str, str, str]]:
    """Return (index, theme, name, region, style) from additions/*/manifest.txt."""
    rows: list[tuple[int, str, str, str, str]] = []
    line_re = re.compile(
        r"^(\d{2})\.\s+(.+?)\s+—\s+(.+?)\s+—\s+(.+?)\s+—\s+(.+)$"
    )
    for folder in sorted(ADDITIONS.glob("foundations_regional_round_*_named")):
        text = (folder / "manifest.txt").read_text(encoding="utf-8")
        for line in text.splitlines():
            m = line_re.match(line.strip())
            if not m:
                continue
            idx = int(m.group(1))
            theme, name, region, style = (
                m.group(2).strip(),
                m.group(3).strip(),
                m.group(4).strip(),
                m.group(5).strip(),
            )
            rows.append((idx, theme, name, region, style))
    rows.sort(key=lambda r: r[0])
    if [r[0] for r in rows] != list(range(1, 41)):
        raise SystemExit(f"Expected indices 1..40, got {[r[0] for r in rows]}")
    return rows


def find_source_webp(idx: int) -> Path:
    prefix = f"{idx:02d}_"
    matches = list(ADDITIONS.glob(f"foundations_regional_round_*_named/{prefix}*.webp"))
    if len(matches) != 1:
        raise FileNotFoundError(f"Expected 1 webp for {prefix}, got {matches}")
    return matches[0]


def build_design(
    *,
    theme: str,
    theme_code: str,
    name: str,
    region_name: str,
    style: str,
    seq: int,
    code: str,
    region_rels: dict[str, tuple[list[str], list[str]]],
) -> dict:
    region_code = REGION_NAME_TO_CODE[region_name]
    affinity, hostility = region_rels.get(region_code, ([], []))
    internal_id = f"{theme_code}-{code}-{ID_TOKEN}-{seq:04d}"
    prompt = (
        f"Give me an image with {name} in {style.lower()} style with a standard "
        f"finish and no effect. Use a background that is visually related to {name}. "
        f"No borders, no frames. The subject should be horizontally and vertically "
        f"centered. The subject should fill around 2/4 of the total image size. "
        f"The image must use a 1:1 aspect ratio in webp format and named {internal_id}.webp"
    )
    return {
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
        "finish": "Standard",
        "color": COLOR,
        "effect": "None",
        "selectionWeight": weight_for(internal_id),
        "series": SERIES_DISPLAY,
        "worldState": "Active",
        "seasonState": "Active",
        "artworkPrompt": prompt,
        "loreDescription": (
            f"A collectible {name} Arcori generation I from the {theme} {SERIES_DISPLAY}."
        ),
        "legacy": dict(LEGACY),
    }


def main() -> None:
    assert ADDITIONS.is_dir(), ADDITIONS
    assert ART_ROOT.is_dir(), ART_ROOT
    region_rels = load_region_rels()
    rows = parse_manifests()

    used_codes: set[str] = set()
    for path in SERIES_JSON.glob("*.json"):
        doc = json.loads(path.read_text(encoding="utf-8"))
        for d in doc.get("designs") or []:
            if isinstance(d, dict) and d.get("designCode"):
                used_codes.add(str(d["designCode"]))

    for idx, theme, name, region, style in rows:
        theme_code = THEME_CODES[theme]
        json_path = SERIES_JSON / f"{theme.lower()}.json"
        doc = json.loads(json_path.read_text(encoding="utf-8"))
        designs = list(doc.get("designs") or [])

        # Idempotent: skip if this seq already present for the theme.
        seq_token = f"-{SEQ:04d}"
        if any(
            str(d.get("internalId") or "").endswith(seq_token)
            for d in designs
            if isinstance(d, dict)
        ):
            print(f"skip existing seq {theme}/{SEQ:04d}")
            continue

        code = design_code(name, used_codes)
        design = build_design(
            theme=theme,
            theme_code=theme_code,
            name=name,
            region_name=region,
            style=style,
            seq=SEQ,
            code=code,
            region_rels=region_rels,
        )
        designs.append(design)
        doc["designs"] = designs
        doc["catalog"] = f"{theme} {SERIES_DISPLAY}"
        doc["theme"] = theme
        doc["series"] = SERIES_KEY
        doc["themeCode"] = theme_code
        json_path.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")

        src = find_source_webp(idx)
        dest_dir = ART_ROOT / theme.lower()
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = dest_dir / f"{design['internalId']}.webp"
        if dest.exists():
            dest.unlink()
        shutil.copy2(str(src), str(dest))
        print(
            f"ok {idx:02d} {src.name} -> {dest.relative_to(ART_ROOT)} "
            f"weight={design['selectionWeight']}"
        )

    # Verify counts
    total = 0
    for path in sorted(SERIES_JSON.glob("*.json")):
        n = len(json.loads(path.read_text(encoding="utf-8")).get("designs") or [])
        total += n
        art_n = len(list((ART_ROOT / path.stem).glob("*.webp")))
        if n != art_n:
            print(f"WARN {path.stem}: json={n} art={art_n}")
    print(f"done foundations designs={total}")


if __name__ == "__main__":
    main()
