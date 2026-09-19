#!/usr/bin/env python3
"""Import Civilizations series (SER004) from assets/images/arcori/additions.

Default: append Ashdrift/Everlight named items (minus near-dups).
`--bootstrap`: original 20×3 scenic/item rounds.
"""

from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

from import_foundations_series import (
    REGION_NAME_TO_CODE,
    THEMES_META,
    design_code,
    design_family,
    load_region_rels,
    update_themes_meta,
)

REPO = Path(__file__).resolve().parents[3]
ADDITIONS = REPO / "assets" / "images" / "arcori" / "additions"
ART_ROOT = REPO / "assets" / "images" / "arcori" / "004_civilizations"
SERIES_JSON = (
    REPO
    / "app_codebase"
    / "python_base_05"
    / "bin"
    / "modules"
    / "catalog"
    / "data"
    / "series"
    / "civilizations"
)
TYPO_ART = REPO / "assets" / "images" / "arcori" / "004_civilizatiions"

SERIES_KEY = "Civilizations"
SERIES_DISPLAY = "Civilizations Series"
ID_TOKEN = "SER004"
LEGACY = {"preservationRequirement": 300, "closureMilestone": 600}
COLOR = "#8B7355"

# Unique vs Genesis/Pioneers/Foundations (Council/Harvest/Discovery already taken).
THEME_CODES: dict[str, str] = {
    "Capital": "CAP",
    "Districts": "DST",
    "Guilds": "GLD",
    "Markets": "MKT",
    "Council": "CCL",
    "Archives": "ARC",
    "Monuments": "MON",
    "Roads": "ROD",
    "Harbors": "HBR",
    "Strongholds": "SGH",
    "Academies": "ACA",
    "Temples": "TMP",
    "Heraldry": "HLD",
    "Festivals": "FES",
    "Customs": "CUS",
    "Watchers": "WCH",
    "Envoys": "ENV",
    "Craftsmanship": "CFM",
    "Borders": "BOR",
    "Dynasties": "DYN",
}

# Official Civilizations theme lore (catalog + Velora).
THEME_LORE: dict[str, str] = {
    "Capital": (
        "The main heart of a region's civilization; its largest and most "
        "symbolic settlement."
    ),
    "Districts": (
        "Different quarters of society: trade, learning, worship, craft, "
        "residence, and governance."
    ),
    "Guilds": (
        "Organized groups of makers, builders, traders, keepers, healers, "
        "or specialists."
    ),
    "Markets": (
        "Bustling centers of exchange, barter, rare goods, and regional identity."
    ),
    "Council": (
        "The ruling or guiding body that shapes the direction of a civilization."
    ),
    "Archives": (
        "Places where memory, records, maps, and truths are preserved."
    ),
    "Monuments": (
        "Great structures built to honor victories, origins, myths, or heroes."
    ),
    "Roads": (
        "The physical links that connect settlements, regions, and distant peoples."
    ),
    "Harbors": (
        "Docks, piers, river stations, or bayfront hubs for travel and trade."
    ),
    "Strongholds": (
        "Fortified places that guard a civilization's borders, treasures, or secrets."
    ),
    "Academies": (
        "Centers of learning, skill, discipline, and regional philosophy."
    ),
    "Temples": (
        "Sacred places devoted to belief, ritual, devotion, and mystery."
    ),
    "Heraldry": (
        "Symbols, banners, emblems, and visual identities of each civilization."
    ),
    "Festivals": (
        "Public celebrations that reveal joy, tradition, memory, and community."
    ),
    "Customs": (
        "Daily rituals, habits, greetings, and practices that define regional culture."
    ),
    "Watchers": (
        "Guardians, patrols, sentinels, or spiritual protectors who oversee the land."
    ),
    "Envoys": (
        "Diplomats, messengers, and representatives connecting one civilization "
        "to another."
    ),
    "Craftsmanship": (
        "The signature objects, tools, clothing, ornaments, and artistry of a people."
    ),
    "Borders": (
        "The edges where one civilization ends and another begins — often tense "
        "or symbolic."
    ),
    "Dynasties": (
        "Lines of leadership, inherited roles, or long-standing houses that "
        "shaped the civilization."
    ),
}

# (theme_index, seq, theme, name, region, style, source_dir)
# Five filenames used "velora" (the world, not a land). Bound to a real region from the art.
# seq 1 = scenic round, seq 2 = named objects, seq 3 = round-2 objects.
DESIGNS: list[tuple[int, int, str, str, str, str, str]] = [
    # --- seq 1, themes 1–10 ---
    (1, 1, "Capital", "Radiant Capital", "Everlight Grove", "Realistic", "Civilizations_Series_First10_Themes_WebP"),
    (2, 1, "Districts", "Tideside Districts", "Moonwake Bay", "Realistic", "Civilizations_Series_First10_Themes_WebP"),
    (3, 1, "Guilds", "Timber Guilds", "Amberwild", "Realistic", "Civilizations_Series_First10_Themes_WebP"),
    (4, 1, "Markets", "Frost Market Day", "Little Frost", "Realistic", "Civilizations_Series_First10_Themes_WebP"),
    (5, 1, "Council", "Council of Ash", "Ashdrift Hill", "Realistic", "Civilizations_Series_First10_Themes_WebP"),
    (6, 1, "Archives", "Pillar Archives", "Everlight Grove", "Realistic", "Civilizations_Series_First10_Themes_WebP"),
    (7, 1, "Monuments", "Rootstone Monument", "Amberwild", "Realistic", "Civilizations_Series_First10_Themes_WebP"),
    (8, 1, "Roads", "Roads Beneath Ash", "Ashdrift Hill", "Realistic", "Civilizations_Series_First10_Themes_WebP"),
    (9, 1, "Harbors", "Moonwake Harbor", "Moonwake Bay", "Realistic", "Civilizations_Series_First10_Themes_WebP"),
    (10, 1, "Strongholds", "Frostwatch Stronghold", "Little Frost", "Realistic", "Civilizations_Series_First10_Themes_WebP"),
    # --- seq 1, themes 11–20 ---
    (11, 1, "Academies", "Prism Collegium", "Everlight Grove", "Prismatic", "Civilizations_Themes_11-20_Regions_WebP"),
    (12, 1, "Temples", "Temple of the High Moon", "Moonwake Bay", "Watercolor", "Civilizations_Themes_11-20_Regions_WebP"),
    (13, 1, "Heraldry", "Oakcrest Hall", "Amberwild", "Comic", "Civilizations_Themes_11-20_Regions_WebP"),
    (14, 1, "Festivals", "Frostfair", "Little Frost", "Cartoon", "Civilizations_Themes_11-20_Regions_WebP"),
    (15, 1, "Customs", "Lanterns on Grey Water", "Ashdrift Hill", "Realistic", "Civilizations_Themes_11-20_Regions_WebP"),
    (16, 1, "Watchers", "Harbor Watch", "Moonwake Bay", "Retro", "Civilizations_Themes_11-20_Regions_WebP"),
    (17, 1, "Envoys", "Gift of the Living Grove", "Everlight Grove", "Anime", "Civilizations_Themes_11-20_Regions_WebP"),
    (18, 1, "Craftsmanship", "Timbercraft", "Amberwild", "Low Poly", "Civilizations_Themes_11-20_Regions_WebP"),
    (19, 1, "Borders", "Ashline Markers", "Ashdrift Hill", "Minimalist", "Civilizations_Themes_11-20_Regions_WebP"),
    (20, 1, "Dynasties", "Winter Throne", "Little Frost", "Pixel Art", "Civilizations_Themes_11-20_Regions_WebP"),
    # --- seq 2, themes 1–10 ---
    (1, 2, "Capital", "Luminous Seat", "Everlight Grove", "Realistic", "arcori_civilizations_first10_named_webp"),
    (2, 2, "Districts", "Civic Medallions", "Everlight Grove", "Realistic", "arcori_civilizations_first10_named_webp"),
    (3, 2, "Guilds", "Guild Table", "Amberwild", "Realistic", "arcori_civilizations_first10_named_webp"),
    (4, 2, "Markets", "Tide Trade Stall", "Moonwake Bay", "Realistic", "arcori_civilizations_first10_named_webp"),
    (5, 2, "Council", "Frost Council", "Little Frost", "Realistic", "arcori_civilizations_first10_named_webp"),
    (6, 2, "Archives", "Ashen Records", "Ashdrift Hill", "Realistic", "arcori_civilizations_first10_named_webp"),
    (7, 2, "Monuments", "Prismatic Honors", "Everlight Grove", "Prismatic", "arcori_civilizations_first10_named_webp"),
    (8, 2, "Roads", "Wayfinder Kit", "Amberwild", "Pixel Art", "arcori_civilizations_first10_named_webp"),
    (9, 2, "Harbors", "Harbor Logbook", "Moonwake Bay", "Realistic", "arcori_civilizations_first10_named_webp"),
    (10, 2, "Strongholds", "Crystal Bastion", "Everlight Grove", "Realistic", "arcori_civilizations_first10_named_webp"),
    # --- seq 2, themes 11–20 ---
    (11, 2, "Academies", "Scholar's Light", "Everlight Grove", "Realistic", "arcori_civilizations_second10_named_webp"),
    (12, 2, "Temples", "Moon Tide Shrine", "Moonwake Bay", "Realistic", "arcori_civilizations_second10_named_webp"),
    (13, 2, "Heraldry", "Civilization Crests", "Little Frost", "Realistic", "arcori_civilizations_second10_named_webp"),
    (14, 2, "Festivals", "Prismatic Gathering", "Amberwild", "Prismatic", "arcori_civilizations_second10_named_webp"),
    (15, 2, "Customs", "Winter Rituals", "Little Frost", "Realistic", "arcori_civilizations_second10_named_webp"),
    (16, 2, "Watchers", "Ashen Sentinels", "Ashdrift Hill", "Realistic", "arcori_civilizations_second10_named_webp"),
    (17, 2, "Envoys", "Diplomatic Kit", "Amberwild", "Cartoon", "arcori_civilizations_second10_named_webp"),
    (18, 2, "Craftsmanship", "Artisan Bench", "Amberwild", "Realistic", "arcori_civilizations_second10_named_webp"),
    (19, 2, "Borders", "Boundary Markers", "Everlight Grove", "Pixel Art", "arcori_civilizations_second10_named_webp"),
    (20, 2, "Dynasties", "Heirloom Regalia", "Everlight Grove", "Realistic", "arcori_civilizations_second10_named_webp"),
    # --- seq 3, themes 1–10 ---
    (1, 3, "Capital", "Ceremonial City Key", "Everlight Grove", "Realistic", "arcori_civilizations_first10_round2_named_webp"),
    (2, 3, "Districts", "Sixfold District Emblem", "Little Frost", "Realistic", "arcori_civilizations_first10_round2_named_webp"),
    (3, 3, "Guilds", "Guildhall Emblem", "Amberwild", "Realistic", "arcori_civilizations_first10_round2_named_webp"),
    (4, 3, "Markets", "Tide Market Balance", "Moonwake Bay", "Realistic", "arcori_civilizations_first10_round2_named_webp"),
    (5, 3, "Council", "Five Gem Council Staff", "Little Frost", "Realistic", "arcori_civilizations_first10_round2_named_webp"),
    (6, 3, "Archives", "Ashbound Archive Tome", "Ashdrift Hill", "Realistic", "arcori_civilizations_first10_round2_named_webp"),
    (7, 3, "Monuments", "Radiant Memory Obelisk", "Everlight Grove", "Realistic", "arcori_civilizations_first10_round2_named_webp"),
    (8, 3, "Roads", "Forest Waymarker", "Amberwild", "Realistic", "arcori_civilizations_first10_round2_named_webp"),
    (9, 3, "Harbors", "Harbor Guiding Lantern", "Moonwake Bay", "Realistic", "arcori_civilizations_first10_round2_named_webp"),
    (10, 3, "Strongholds", "Fortress Lockshield", "Little Frost", "Realistic", "arcori_civilizations_first10_round2_named_webp"),
    # --- seq 3, themes 11–20 ---
    (11, 3, "Academies", "Celestial Academy Astrolabe", "Everlight Grove", "Realistic", "arcori_civilizations_second10_round2_named_webp"),
    (12, 3, "Temples", "Moontide Temple Censer", "Moonwake Bay", "Realistic", "arcori_civilizations_second10_round2_named_webp"),
    (13, 3, "Heraldry", "Oakcrest Heraldic Shield", "Amberwild", "Realistic", "arcori_civilizations_second10_round2_named_webp"),
    (14, 3, "Festivals", "Harvestlight Festival Lantern", "Amberwild", "Realistic", "arcori_civilizations_second10_round2_named_webp"),
    (15, 3, "Customs", "Winter Hearth Teapot", "Little Frost", "Realistic", "arcori_civilizations_second10_round2_named_webp"),
    (16, 3, "Watchers", "Ashen Sentinel Helm", "Ashdrift Hill", "Realistic", "arcori_civilizations_second10_round2_named_webp"),
    (17, 3, "Envoys", "Harbor Envoy Scrollcase", "Moonwake Bay", "Realistic", "arcori_civilizations_second10_round2_named_webp"),
    (18, 3, "Craftsmanship", "Leafforged Craft Hammer", "Amberwild", "Realistic", "arcori_civilizations_second10_round2_named_webp"),
    (19, 3, "Borders", "Ashlands Boundary Stone", "Ashdrift Hill", "Realistic", "arcori_civilizations_second10_round2_named_webp"),
    (20, 3, "Dynasties", "Sunleaf Dynasty Crown", "Everlight Grove", "Realistic", "arcori_civilizations_second10_round2_named_webp"),
]

# Near-dups vs existing SER004 art — not imported.
DROPPED_ITEM_NUMS = {2, 5, 12, 20, 21, 23}

# (file_num, theme, name, region, style) — Ashdrift 01–20 / Everlight 21–40 minus dropped.
BATCH2_DESIGNS: list[tuple[int, str, str, str, str]] = [
    (1, "Monuments", "Memory Ash Urn", "Ashdrift Hill", "Realistic"),
    (3, "Dynasties", "Sooted Signet Ring", "Ashdrift Hill", "Realistic"),
    (4, "Watchers", "Ruinkeeper Lantern", "Ashdrift Hill", "Realistic"),
    (6, "Roads", "Echo Compass", "Ashdrift Hill", "Realistic"),
    (7, "Temples", "Ashfall Prayer Mask", "Ashdrift Hill", "Realistic"),
    (8, "Borders", "Fractured Seal Tablet", "Ashdrift Hill", "Realistic"),
    (9, "Council", "Forgotten Council Bell", "Ashdrift Hill", "Realistic"),
    (10, "Envoys", "Dustbound Scroll Case", "Ashdrift Hill", "Realistic"),
    (11, "Customs", "Emberless Brazier", "Ashdrift Hill", "Realistic"),
    (13, "Strongholds", "Blackened Relic Key", "Ashdrift Hill", "Realistic"),
    (14, "Heraldry", "Hollow Oath Medallion", "Ashdrift Hill", "Realistic"),
    (15, "Craftsmanship", "Ruinsmith Chisel", "Ashdrift Hill", "Realistic"),
    (16, "Customs", "Faded Mourning Banner", "Ashdrift Hill", "Realistic"),
    (17, "Guilds", "Ashmarked Ledger", "Ashdrift Hill", "Realistic"),
    (18, "Archives", "Obsidian Memory Gem", "Ashdrift Hill", "Realistic"),
    (19, "Watchers", "Watchers Iron Token", "Ashdrift Hill", "Realistic"),
    (22, "Capital", "Guardian Scepter", "Everlight Grove", "Realistic"),
    (24, "Academies", "Crystal Academy Orb", "Everlight Grove", "Realistic"),
    (25, "Districts", "Pillar Sigil Medallion", "Everlight Grove", "Realistic"),
    (26, "Council", "Radiant Council Staff", "Everlight Grove", "Realistic"),
    (27, "Customs", "Harmony Seal", "Everlight Grove", "Realistic"),
    (28, "Harbors", "Beacon Lantern", "Everlight Grove", "Realistic"),
    (29, "Dynasties", "Sunleaf Tiara", "Everlight Grove", "Low Poly"),
    (30, "Heraldry", "Lightwoven Banner", "Everlight Grove", "Realistic"),
    (31, "Archives", "Emerald Archive Key", "Everlight Grove", "Realistic"),
    (32, "Temples", "Prism Chalice", "Everlight Grove", "Realistic"),
    (33, "Heraldry", "Goldleaf Heraldic Shield", "Everlight Grove", "Realistic"),
    (34, "Temples", "Crystal Reliquary", "Everlight Grove", "Realistic"),
    (35, "Roads", "Grovekeeper Compass", "Everlight Grove", "Realistic"),
    (36, "Markets", "Ivory Trade Scale", "Everlight Grove", "Realistic"),
    (37, "Monuments", "Pillarstone Tablet", "Everlight Grove", "Realistic"),
    (38, "Craftsmanship", "Living Vine Ring", "Everlight Grove", "Realistic"),
    (39, "Festivals", "Unity Bell", "Everlight Grove", "Realistic"),
    (40, "Academies", "Celestial Orrery", "Everlight Grove", "Realistic"),
]

ITEM_SOURCE_DIRS = (
    "arcori_civilization_items_ashdrift_01_10_named_webp",
    "arcori_civilization_items_ashdrift_11_20_named_webp",
    "arcori_civilization_items_everlight_21_30_named_webp",
    "arcori_civilization_items_everlight_31_40_named_webp",
)

EXPECTED_AFTER_BATCH2 = 94


def item_source_dir(file_num: int) -> str:
    if 1 <= file_num <= 10:
        return ITEM_SOURCE_DIRS[0]
    if 11 <= file_num <= 20:
        return ITEM_SOURCE_DIRS[1]
    if 21 <= file_num <= 30:
        return ITEM_SOURCE_DIRS[2]
    if 31 <= file_num <= 40:
        return ITEM_SOURCE_DIRS[3]
    raise ValueError(f"item file_num out of range: {file_num}")


def weight_for(internal_id: str) -> float:
    n = int(hashlib.md5(internal_id.encode("utf-8")).hexdigest()[:8], 16) % 71
    return round(3.0 + n * 0.1, 1)


def find_source(theme_index: int, source_dir: str) -> Path:
    folder = ADDITIONS / source_dir
    matches = list(folder.glob(f"{theme_index:02d}_*.webp"))
    if len(matches) != 1:
        raise FileNotFoundError(
            f"Expected 1 webp for {source_dir}/{theme_index:02d}_*, got {matches}"
        )
    return matches[0]


def seq_of(design: dict) -> int:
    return int(str(design["internalId"]).rsplit("-", 1)[-1])


def load_theme_docs() -> dict[str, dict]:
    docs: dict[str, dict] = {}
    for theme, theme_code in THEME_CODES.items():
        path = SERIES_JSON / f"{theme.lower()}.json"
        if not path.is_file():
            raise SystemExit(f"Missing series JSON {path}")
        doc = json.loads(path.read_text(encoding="utf-8"))
        if doc.get("themeCode") != theme_code:
            raise SystemExit(f"themeCode mismatch in {path}")
        docs[theme] = doc
    return docs


def write_theme_doc(theme: str, doc: dict) -> None:
    designs = list(doc.get("designs") or [])
    designs.sort(key=seq_of)
    ordered = {
        "catalog": doc.get("catalog"),
        "theme": doc.get("theme"),
        "series": doc.get("series"),
        "themeCode": doc.get("themeCode"),
        "loreDescription": doc.get("loreDescription") or THEME_LORE[theme],
        "version": doc.get("version", 1),
        "designs": designs,
    }
    path = SERIES_JSON / f"{theme.lower()}.json"
    path.write_text(json.dumps(ordered, indent=2) + "\n", encoding="utf-8")


def assert_catalog_sane(expected: int) -> int:
    total = 0
    for path in SERIES_JSON.glob("*.json"):
        doc = json.loads(path.read_text(encoding="utf-8"))
        designs = doc.get("designs") or []
        total += len(designs)
        for d in designs:
            code = (d.get("location") or {}).get("regionCode")
            if code in {None, "", "VEL", "VLR"}:
                raise SystemExit(f"Bad region on {d.get('internalId')}: {code}")
    if total != expected:
        raise SystemExit(f"Expected {expected} designs, got {total}")
    return total


def quarantine_dropped_items() -> None:
    dest = ADDITIONS / "_dropped_near_dups"
    dest.mkdir(exist_ok=True)
    for file_num in sorted(DROPPED_ITEM_NUMS):
        folder = ADDITIONS / item_source_dir(file_num)
        matches = list(folder.glob(f"{file_num:02d}_*.webp")) if folder.is_dir() else []
        if len(matches) != 1:
            raise FileNotFoundError(
                f"Expected 1 dropped webp {file_num:02d}_* in {folder.name}, got {matches}"
            )
        src = matches[0]
        target = dest / src.name
        if target.exists():
            target.unlink()
        shutil.move(str(src), str(target))
        print(f"dropped {src.name} -> additions/_dropped_near_dups/")


def archive_item_source_dirs() -> None:
    archive = ADDITIONS / "_imported_civilizations"
    archive.mkdir(exist_ok=True)
    for dirname in ITEM_SOURCE_DIRS:
        src_dir = ADDITIONS / dirname
        if not src_dir.is_dir():
            continue
        dest_dir = archive / dirname
        if dest_dir.exists():
            shutil.rmtree(dest_dir)
        shutil.move(str(src_dir), str(dest_dir))
        print(f"archived additions/{dirname}")


def import_item_batch() -> None:
    """Append Ashdrift/Everlight named items (minus near-dups) onto existing SER004 JSON."""
    if len(BATCH2_DESIGNS) != EXPECTED_AFTER_BATCH2 - 60:
        raise SystemExit(
            f"BATCH2 has {len(BATCH2_DESIGNS)} rows, expected {EXPECTED_AFTER_BATCH2 - 60}"
        )
    batch_nums = {row[0] for row in BATCH2_DESIGNS}
    if batch_nums & DROPPED_ITEM_NUMS:
        raise SystemExit(f"BATCH2 includes dropped nums {batch_nums & DROPPED_ITEM_NUMS}")
    if batch_nums | DROPPED_ITEM_NUMS != set(range(1, 41)):
        missing = set(range(1, 41)) - (batch_nums | DROPPED_ITEM_NUMS)
        extra = (batch_nums | DROPPED_ITEM_NUMS) - set(range(1, 41))
        raise SystemExit(f"Item nums incomplete missing={missing} extra={extra}")

    assert ADDITIONS.is_dir(), ADDITIONS
    ART_ROOT.mkdir(parents=True, exist_ok=True)
    region_rels = load_region_rels()
    docs = load_theme_docs()
    used_codes: set[str] = set()
    next_seq: dict[str, int] = {}
    for theme, doc in docs.items():
        designs = list(doc.get("designs") or [])
        used_codes.update(str(d.get("designCode") or "") for d in designs)
        next_seq[theme] = max((seq_of(d) for d in designs), default=0) + 1

    quarantine_dropped_items()

    for file_num, theme, name, region, style in BATCH2_DESIGNS:
        theme_code = THEME_CODES[theme]
        existing_names = {str(d.get("design") or "") for d in docs[theme].get("designs") or []}
        if name in existing_names:
            raise SystemExit(f"Design already present: {theme}/{name}")
        code = design_code(name, used_codes)
        used_codes.add(code)
        seq = next_seq[theme]
        next_seq[theme] = seq + 1
        design, art_stem = build_design(
            theme=theme,
            theme_code=theme_code,
            name=name,
            region_name=region,
            style=style,
            seq=seq,
            code=code,
            region_rels=region_rels,
        )
        docs[theme].setdefault("designs", []).append(design)
        src = find_source(file_num, item_source_dir(file_num))
        dest_dir = ART_ROOT / theme.lower()
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = dest_dir / f"{art_stem}.webp"
        if dest.exists() and dest.resolve() != src.resolve():
            dest.unlink()
        shutil.copy2(src, dest)
        print(f"art {src.name} -> {dest.relative_to(ART_ROOT.parent)}")

    for theme, doc in docs.items():
        write_theme_doc(theme, doc)
        print(
            f"json series/civilizations/{theme.lower()}.json "
            f"({len(doc.get('designs') or [])} designs)"
        )

    archive_item_source_dirs()
    total = assert_catalog_sane(EXPECTED_AFTER_BATCH2)
    print(f"ok {total} civilizations designs")


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
        f"Give me an image with {name} in {style.lower()} style with a standard "
        f"finish and no effect. Use a background that is visually related to {name}. "
        f"No borders, no frames. The subject should be horizontally and vertically "
        f"centered. The subject should fill around 2/4 of the total image size. "
        f"The image must use a 1:1 aspect ratio in webp format and named {internal_id}.webp"
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
    return design, art_stem


def apply_theme_lore_to_meta() -> None:
    """Stamp Civilizations theme lore onto 00_themes_subthemes.json by themeCode."""
    meta = json.loads(THEMES_META.read_text(encoding="utf-8"))
    lore_by_code = {THEME_CODES[name]: text for name, text in THEME_LORE.items()}
    for row in meta.get("themes") or []:
        if not isinstance(row, dict):
            continue
        code = str(row.get("themeCode") or "").strip()
        if code in lore_by_code:
            row["loreDescription"] = lore_by_code[code]
    THEMES_META.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")


def apply_theme_lore_to_series_json() -> None:
    for theme, lore in THEME_LORE.items():
        path = SERIES_JSON / f"{theme.lower()}.json"
        if not path.is_file():
            continue
        doc = json.loads(path.read_text(encoding="utf-8"))
        ordered = {
            "catalog": doc.get("catalog"),
            "theme": doc.get("theme"),
            "series": doc.get("series"),
            "themeCode": doc.get("themeCode"),
            "loreDescription": lore,
            "version": doc.get("version", 1),
            "designs": doc.get("designs") or [],
        }
        path.write_text(json.dumps(ordered, indent=2) + "\n", encoding="utf-8")


def bootstrap() -> None:
    assert ADDITIONS.is_dir(), ADDITIONS
    if TYPO_ART.exists() and not any(TYPO_ART.iterdir()):
        TYPO_ART.rmdir()
        print(f"removed empty typo dir {TYPO_ART.name}")

    ART_ROOT.mkdir(parents=True, exist_ok=True)
    SERIES_JSON.mkdir(parents=True, exist_ok=True)
    region_rels = load_region_rels()

    by_theme: dict[str, list[dict]] = {}
    theme_order: list[str] = []
    used_codes: set[str] = set()
    moved_dirs: set[str] = set()

    for theme_index, seq, theme, name, region, style, source_dir in DESIGNS:
        if region.lower() == "velora":
            raise SystemExit(f"Refusing Velora region for {name}")
        theme_code = THEME_CODES[theme]
        if theme not in by_theme:
            by_theme[theme] = []
            theme_order.append(theme)
        used_in_theme = {d["designCode"] for d in by_theme[theme]}
        code = design_code(name, used_in_theme | used_codes)
        used_codes.add(code)
        design, art_stem = build_design(
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

        src = find_source(theme_index, source_dir)
        dest_dir = ART_ROOT / theme.lower()
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = dest_dir / f"{art_stem}.webp"
        if dest.exists() and dest.resolve() != src.resolve():
            dest.unlink()
        shutil.copy2(src, dest)
        print(f"art {src.name} -> {dest.relative_to(ART_ROOT.parent)}")
        moved_dirs.add(source_dir)

    for theme in theme_order:
        designs = by_theme[theme]
        designs.sort(key=lambda d: int(str(d["internalId"]).rsplit("-", 1)[-1]))
        theme_code = THEME_CODES[theme]
        doc = {
            "catalog": f"{theme} {SERIES_DISPLAY}",
            "theme": theme,
            "series": SERIES_KEY,
            "themeCode": theme_code,
            "loreDescription": THEME_LORE[theme],
            "version": 1,
            "designs": designs,
        }
        out = SERIES_JSON / f"{theme.lower()}.json"
        out.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
        print(f"json {out.relative_to(REPO)} ({len(designs)} designs)")

    update_themes_meta([(t, THEME_CODES[t]) for t in theme_order])
    apply_theme_lore_to_meta()
    print(f"updated {THEMES_META.relative_to(REPO)}")

    archive = ADDITIONS / "_imported_civilizations"
    archive.mkdir(exist_ok=True)
    for dirname in sorted(moved_dirs):
        src_dir = ADDITIONS / dirname
        dest_dir = archive / dirname
        if dest_dir.exists():
            shutil.rmtree(dest_dir)
        shutil.move(str(src_dir), str(dest_dir))
        print(f"archived additions/{dirname}")

    total = assert_catalog_sane(60)
    print(f"ok {total} civilizations designs")


if __name__ == "__main__":
    import sys

    if "--bootstrap" in sys.argv:
        bootstrap()
    else:
        import_item_batch()
