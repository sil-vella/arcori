#!/usr/bin/env python3
"""One-shot: Foundations series JSON + rename art under 003_foundations/<theme>/."""

from __future__ import annotations

import json
import re
import shutil
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
ART_ROOT = REPO / "assets" / "images" / "arcori" / "003_foundations"
SERIES_JSON = (
    REPO
    / "app_codebase"
    / "python_base_05"
    / "bin"
    / "modules"
    / "catalog"
    / "data"
    / "series"
    / "foundations"
)
THEMES_META = (
    REPO
    / "app_codebase"
    / "python_base_05"
    / "bin"
    / "modules"
    / "catalog"
    / "data"
    / "00_themes_subthemes.json"
)
REGIONS_META = (
    REPO
    / "app_codebase"
    / "python_base_05"
    / "bin"
    / "modules"
    / "catalog"
    / "data"
    / "01_regions.json"
)

SERIES_KEY = "Foundations"
SERIES_DISPLAY = "Foundations Series"
ID_TOKEN = "SER003"
LEGACY = {"preservationRequirement": 250, "closureMilestone": 500}
COLOR = "#C6A15B"
WEIGHT = 3.0

# Theme display name → themeCode (Music reuses Genesis MUS).
THEME_CODES: dict[str, str] = {
    "Hearth": "HEA",
    "Shelter": "SHE",
    "Harvest": "HAR",
    "Craft": "CRA",
    "Stonework": "STN",
    "Wayfinding": "WAY",
    "Trade": "TRD",
    "Kinship": "KNS",
    "Alliance": "ALL",
    "Tradition": "TRN",
    "Ceremony": "CER",
    "Knowledge": "KNO",
    "Storytelling": "STY",
    "Stewardship": "STE",
    "Discovery": "DIS",
    "Settlement": "SET",
    "Community": "CMY",
    "Language": "LAN",
    "Memory": "MEM",
    "Identity": "IDN",
    "Belief": "BEL",
    "Devotion": "DEV",
    "Hospitality": "HOS",
    "Celebration": "CEL",
    "Music": "MUS",
    "Artistry": "ART",
    "Navigation": "NAV",
    "Exploration": "EXP",
    "Commerce": "CMC",
    "Diplomacy": "DIP",
    "Council": "COU",
    "Resilience": "RES",
    "Innovation": "INN",
    "Inheritance": "INH",
    "Ingenuity": "IGY",
    "Leadership": "LED",
    "Law": "LAW",
    "Sanctuary": "SAN",
    "Legacy": "LEG",
    "Unity": "UNI",
}

REGION_NAME_TO_CODE = {
    "Amberwild": "AMB",
    "Moonwake Bay": "MWB",
    "Everlight Grove": "EVG",
    "Little Frost": "LFR",
    "Ashdrift Hill": "ASH",
}

# index (1-40) → (theme, name, region, style) for v1 then v2
MANIFEST_V1: dict[int, tuple[str, str, str, str]] = {
    1: ("Hearth", "Emberhome", "Amberwild", "Realistic"),
    2: ("Shelter", "Stormward Refuge", "Moonwake Bay", "Comic"),
    3: ("Harvest", "Evergold Gathering", "Everlight Grove", "Anime"),
    4: ("Craft", "The Patient Hand", "Moonwake Bay", "Watercolor"),
    5: ("Stonework", "Arch of Returning Paths", "Amberwild", "Minimalist"),
    6: ("Wayfinding", "The Impossible Beacon", "Everlight Grove", "Neon"),
    7: ("Trade", "Sunmarket Exchange", "Everlight Grove", "Cartoon"),
    8: ("Kinship", "Fireside Kin", "Little Frost", "Pixel Art"),
    9: ("Alliance", "Pact of Two Lands", "Everlight Grove", "Low Poly"),
    10: ("Tradition", "The Golden Passing", "Everlight Grove", "Chibi"),
    11: ("Ceremony", "Rite of the First Light", "Everlight Grove", "Graffiti"),
    12: ("Knowledge", "Archive of Many Lights", "Everlight Grove", "Prismatic"),
    13: ("Storytelling", "Fireside Chronicle", "Amberwild", "Retro"),
    14: ("Stewardship", "Keeper of the Young Bough", "Amberwild", "Realistic"),
    15: ("Discovery", "Circle Beneath the Wild", "Amberwild", "Comic"),
    16: ("Settlement", "Dawnstone Haven", "Moonwake Bay", "Anime"),
    17: ("Community", "The Common Table", "Little Frost", "Watercolor"),
    18: ("Language", "Signs Across the Tide", "Moonwake Bay", "Minimalist"),
    19: ("Memory", "Echoes That Remain", "Ashdrift Hill", "Neon"),
    20: ("Identity", "The Chosen Self", "Everlight Grove", "Cartoon"),
    21: ("Belief", "The Unanswered Flame", "Ashdrift Hill", "Pixel Art"),
    22: ("Devotion", "Vigil of the Last Light", "Everlight Grove", "Low Poly"),
    23: ("Hospitality", "Hearth for the Wanderer", "Little Frost", "Chibi"),
    24: ("Celebration", "Festival of Joined Lights", "Everlight Grove", "Graffiti"),
    25: ("Music", "Chorus of Crystal Skies", "Everlight Grove", "Prismatic"),
    26: ("Artistry", "The Remembered Canvas", "Amberwild", "Retro"),
    27: ("Navigation", "Keeper of the Moon Charts", "Moonwake Bay", "Realistic"),
    28: ("Exploration", "Beyond the Golden Path", "Amberwild", "Comic"),
    29: ("Commerce", "Market of Returning Tides", "Moonwake Bay", "Anime"),
    30: ("Diplomacy", "Accord Beneath the Pillars", "Everlight Grove", "Watercolor"),
    31: ("Council", "Circle of Many Voices", "Everlight Grove", "Minimalist"),
    32: ("Resilience", "The Town That Rose Again", "Little Frost", "Neon"),
    33: ("Innovation", "The First Turning", "Everlight Grove", "Cartoon"),
    34: ("Inheritance", "What the Elders Carried", "Amberwild", "Pixel Art"),
    35: ("Ingenuity", "Tidewright's Answer", "Moonwake Bay", "Low Poly"),
    36: ("Leadership", "Lantern at the Front", "Little Frost", "Chibi"),
    37: ("Law", "Covenant of Ash and Stone", "Ashdrift Hill", "Graffiti"),
    38: ("Sanctuary", "The Hidden Golden Refuge", "Amberwild", "Prismatic"),
    39: ("Legacy", "Monument of the Last Hand", "Ashdrift Hill", "Retro"),
    40: ("Unity", "When All Lights Become One", "Everlight Grove", "Realistic"),
}

MANIFEST_V2: dict[int, tuple[str, str, str, str]] = {
    1: ("Hearth", "Rootfire Hall", "Amberwild", "Realistic"),
    2: ("Shelter", "Harbor of the Last Lantern", "Moonwake Bay", "Comic"),
    3: ("Harvest", "Bounty Beneath the Pillars", "Everlight Grove", "Anime"),
    4: ("Craft", "The Tidecarver's Instrument", "Moonwake Bay", "Watercolor"),
    5: ("Stonework", "Gate of Golden Stone", "Amberwild", "Minimalist"),
    6: ("Wayfinding", "Path of Five Lights", "Everlight Grove", "Neon"),
    7: ("Trade", "Grovebound Exchange", "Everlight Grove", "Cartoon"),
    8: ("Kinship", "Winterblood Circle", "Little Frost", "Pixel Art"),
    9: ("Alliance", "Bridge of Joined Guardians", "Everlight Grove", "Low Poly"),
    10: ("Tradition", "Keeping of the First Lanterns", "Everlight Grove", "Chibi"),
    11: ("Ceremony", "Procession of Five Flames", "Everlight Grove", "Graffiti"),
    12: ("Knowledge", "Observatory of Living Light", "Everlight Grove", "Prismatic"),
    13: ("Storytelling", "Shadows Beneath Old Boughs", "Amberwild", "Retro"),
    14: ("Stewardship", "Warden of the Quiet Spring", "Amberwild", "Realistic"),
    15: ("Discovery", "Door Within the Stormsplit Tree", "Amberwild", "Comic"),
    16: ("Settlement", "First Lanterns of the New Shore", "Moonwake Bay", "Anime"),
    17: ("Community", "Supper After the Blizzard", "Little Frost", "Watercolor"),
    18: ("Language", "The Shared Signal", "Moonwake Bay", "Minimalist"),
    19: ("Memory", "Faces in Falling Ash", "Ashdrift Hill", "Neon"),
    20: ("Identity", "The Self Woven Freely", "Everlight Grove", "Cartoon"),
    21: ("Belief", "The Seed Beneath the Ash", "Ashdrift Hill", "Pixel Art"),
    22: ("Devotion", "Keeper of the Fading Pillar", "Everlight Grove", "Low Poly"),
    23: ("Hospitality", "The Door Through the Whiteout", "Little Frost", "Chibi"),
    24: ("Celebration", "Night of a Thousand Ribbons", "Everlight Grove", "Graffiti"),
    25: ("Music", "Tidesong Constellation", "Moonwake Bay", "Prismatic"),
    26: ("Artistry", "Forms the Forest Remembered", "Amberwild", "Retro"),
    27: ("Navigation", "Bell Beyond the Fog", "Moonwake Bay", "Realistic"),
    28: ("Exploration", "The Road Under Ash", "Ashdrift Hill", "Comic"),
    29: ("Commerce", "Market Upon the Frozen Canal", "Little Frost", "Anime"),
    30: ("Diplomacy", "The Sapling at the Boundary", "Amberwild", "Watercolor"),
    31: ("Council", "The Circle of Quiet Voices", "Amberwild", "Minimalist"),
    32: ("Resilience", "The Town That Rose by Morning", "Little Frost", "Neon"),
    33: ("Innovation", "The Lantern That Learned the Tide", "Moonwake Bay", "Cartoon"),
    34: ("Inheritance", "The Key Passed Through Winter", "Little Frost", "Pixel Art"),
    35: ("Ingenuity", "The Bridge Woven from Light", "Everlight Grove", "Low Poly"),
    36: ("Leadership", "First Into the White Ash", "Ashdrift Hill", "Chibi"),
    37: ("Law", "The Covenant of Five Lights", "Everlight Grove", "Graffiti"),
    38: ("Sanctuary", "Harbor Beneath the Roots", "Amberwild", "Prismatic"),
    39: ("Legacy", "What the Tide Remembered", "Moonwake Bay", "Retro"),
    40: ("Unity", "When Every Color Became One", "Everlight Grove", "Realistic"),
}


def _words(name: str) -> list[str]:
    return re.findall(r"[A-Za-z0-9]+", name)


_STOP = frozenset(
    {"THE", "A", "AN", "OF", "AND", "FOR", "TO", "IN", "ON", "AT", "BY", "FROM", "WITH"}
)


def _significant_words(name: str) -> list[str]:
    words = _words(name)
    sig = [w for w in words if w.upper() not in _STOP]
    return sig or words


def design_code(name: str, used: set[str]) -> str:
    sig = _significant_words(name)
    candidates: list[str] = []
    if not sig:
        candidates.append("XXX")
    elif len(sig) == 1:
        w = sig[0].upper()
        candidates.extend([w[:3], w[1:4], (w[0] + w[-2:]), w[:2] + "X"])
    else:
        candidates.append("".join(w[0] for w in sig[:3]).upper())
        candidates.append((sig[0][:2] + sig[1][0]).upper())
        candidates.append((sig[0][0] + sig[1][:2]).upper())
        candidates.append(sig[0][:3].upper())
        for w in sig:
            if len(w) >= 4:
                candidates.append(w[:3].upper())
    for i in range(20):
        for base in candidates:
            base = re.sub(r"[^A-Z0-9]", "", base.upper())[:3]
            if len(base) < 3:
                base = (base + "X" * 3)[:3]
            cand = base if i == 0 else f"{base[:2]}{i}"
            cand = cand[:3]
            if cand not in used:
                used.add(cand)
                return cand
    raise RuntimeError(f"Could not allocate designCode for {name!r}")


def design_family(name: str) -> str:
    parts = [p.upper() for p in _words(name)]
    return "_".join(parts) if parts else "UNKNOWN"


def load_region_rels() -> dict[str, tuple[list[str], list[str]]]:
    data = json.loads(REGIONS_META.read_text(encoding="utf-8"))
    out: dict[str, tuple[list[str], list[str]]] = {}
    for row in data.get("regions") or []:
        if not isinstance(row, dict):
            continue
        code = str(row.get("regionCode") or "").strip().upper()
        rel = row.get("relationships") if isinstance(row.get("relationships"), dict) else {}
        aff = rel.get("affinity") if isinstance(rel, dict) else []
        hos = rel.get("hostility") if isinstance(rel, dict) else []
        out[code] = (
            [str(x) for x in aff] if isinstance(aff, list) else [],
            [str(x) for x in hos] if isinstance(hos, list) else [],
        )
    return out


def find_source_webp(theme_index: int, is_v2: bool) -> Path:
    prefix = f"{theme_index:02d}_"
    matches = []
    for path in ART_ROOT.glob("*.webp"):
        if not path.name.startswith(prefix):
            # also allow already-moved? only flat files
            continue
        name_l = path.name.lower()
        has_v2 = name_l.endswith("_v2.webp") or "_v2." in name_l
        if is_v2 == has_v2:
            matches.append(path)
    if len(matches) != 1:
        raise FileNotFoundError(
            f"Expected 1 source for theme {theme_index:02d} v2={is_v2}, got {matches}"
        )
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
    subject = name
    prompt = (
        f"Give me an image with {subject} in {style.lower()} style with a standard "
        f"finish and no effect. Use a background that is visually related to {subject}. "
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
        "printedRarity": "Common",
        "selectionWeight": WEIGHT,
        "series": SERIES_DISPLAY,
        "worldState": "Active",
        "seasonState": "Active",
        "artworkPrompt": prompt,
        "loreDescription": (
            f"A collectible {name} Arcori generation I from the {theme} {SERIES_DISPLAY}."
        ),
        "legacy": dict(LEGACY),
    }


def update_themes_meta(new_themes: list[tuple[str, str]]) -> None:
    meta = json.loads(THEMES_META.read_text(encoding="utf-8"))
    existing = {str(t.get("themeCode")): t for t in meta.get("themes") or []}
    for theme, code in new_themes:
        if code == "MUS":
            # Already registered under Genesis Music.
            continue
        if code in existing:
            row = existing[code]
            subs = row.get("subthemes")
            if isinstance(subs, list) and theme not in subs:
                # Keep as-is; Foundations uses theme-as-subtheme on designs.
                pass
            continue
        meta["themes"].append({"theme": theme, "themeCode": code, "subthemes": [theme]})
    meta["themes"] = sorted(meta["themes"], key=lambda t: str(t.get("theme") or ""))
    THEMES_META.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    assert ART_ROOT.is_dir(), ART_ROOT
    region_rels = load_region_rels()
    SERIES_JSON.mkdir(parents=True, exist_ok=True)

    # Move manifests aside so theme dirs stay clean.
    manifest_dir = ART_ROOT / "_manifests"
    manifest_dir.mkdir(exist_ok=True)
    for path in ART_ROOT.glob("manifest*.txt"):
        dest = manifest_dir / path.name
        if path.resolve() != dest.resolve():
            shutil.move(str(path), str(dest))

    by_theme: dict[str, list[dict]] = {}
    used_codes_global: set[str] = set()
    theme_order: list[str] = []

    for idx in range(1, 41):
        for seq, (manifest, is_v2) in ((1, (MANIFEST_V1, False)), (2, (MANIFEST_V2, True))):
            theme, name, region, style = manifest[idx]
            theme_code = THEME_CODES[theme]
            if theme not in by_theme:
                by_theme[theme] = []
                theme_order.append(theme)
            used_in_theme = {d["designCode"] for d in by_theme[theme]}
            used = used_in_theme | used_codes_global
            code = design_code(name, used)
            used_codes_global.add(code)
            design = build_design(
                theme=theme,
                theme_code=theme_code,
                name=name,
                region_name=region,
                style=style,
                seq=seq,
                code=code,
                region_rels=region_rels,
            )
            by_theme[theme].append(design)

            src = find_source_webp(idx, is_v2)
            theme_slug = theme.lower()
            dest_dir = ART_ROOT / theme_slug
            dest_dir.mkdir(parents=True, exist_ok=True)
            dest = dest_dir / f"{design['internalId']}.webp"
            if dest.exists() and dest.resolve() != src.resolve():
                dest.unlink()
            shutil.move(str(src), str(dest))
            print(f"art {src.name} -> {dest.relative_to(ART_ROOT)}")

    for theme in theme_order:
        designs = by_theme[theme]
        theme_code = THEME_CODES[theme]
        doc = {
            "catalog": f"{theme} {SERIES_DISPLAY}",
            "theme": theme,
            "series": SERIES_KEY,
            "themeCode": theme_code,
            "version": 1,
            "designs": designs,
        }
        out = SERIES_JSON / f"{theme.lower()}.json"
        out.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
        print(f"json {out.relative_to(REPO)} ({len(designs)} designs)")

    update_themes_meta([(t, THEME_CODES[t]) for t in theme_order])
    print(f"updated {THEMES_META.relative_to(REPO)}")

    leftover = list(ART_ROOT.glob("*.webp"))
    if leftover:
        raise SystemExit(f"Leftover flat webps: {leftover}")


if __name__ == "__main__":
    main()
