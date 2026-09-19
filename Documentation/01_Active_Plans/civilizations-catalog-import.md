# Civilizations Catalog Import

**Status**: Completed  
**Created**: 2026-09-18  
**Last Updated**: 2026-09-19

## Objective

Import Civilizations series art from `assets/images/arcori/additions` into catalog JSON and numbered theme art dirs (`SER004`).

## Done

- [x] Parse 6 addition folders (20 themes × 3 designs = **60**)
- [x] Write `data/series/civilizations/{theme}.json` (`SER004`, legacy 300/600)
- [x] Copy art to `{themeCode}-{designCode}-SER004-####.webp` under `004_civilizations/{theme}/`
- [x] Register unique theme codes in `00_themes_subthemes.json` (Council → `CCL`, not Foundations `COU`)
- [x] Remap five filenames tagged `velora` (world, not a land) to a real region from the art
- [x] Wire `SERIES_MEDIA_FOLDERS`, `catalog_ids`, Flutter series labels
- [x] Document series in Tech Spec / GDD / Content Bible / World Bible / case study
- [x] Official 20-theme lore on series JSON + `00_themes_subthemes.json` (Velora theme screen)
- [x] Hash + visual near-dup review of 40 Ashdrift/Everlight named items
- [x] Drop 6 near-dups; import remaining **34** (series total **94**)

## Velora filename remaps

Velora is the world. Catalog `location.regionCode` is always one of the five lands:

| Design | Filename said | Bound to | Why |
|--------|---------------|----------|-----|
| Civic Medallions | velora | Everlight Grove | Civic map of the five lands; unused vs Moonwake/Little Frost siblings |
| Wayfinder Kit | velora | Amberwild | Autumn forest trail kit |
| Civilization Crests | velora | Little Frost | Center crest is the snowflake |
| Diplomatic Kit | velora | Amberwild | Wood/leaf envoy desk; unused vs Everlight/Moonwake siblings |
| Boundary Markers | velora | Everlight Grove | Unused vs Ashdrift siblings |

## Item batch (2026-09-19)

40 named items (Ashdrift 01–20, Everlight 21–40). No MD5 copies. Six near-dups quarantined to `additions/_dropped_near_dups/` and not imported:

| Dropped | Closest existing |
|---------|------------------|
| Cracked Archive Codex | Ashbound Archive Tome |
| Burnt Border Stone | Ashlands Boundary Stone |
| Worn Sentinel Helm | Ashen Sentinel Helm |
| Crumbling Milestone | Ashlands Boundary Stone |
| Prism Crown | Sunleaf Dynasty Crown |
| Luminous Astrolabe | Celestial Academy Astrolabe |

The other 34 append as seq `0004+` on the matching civic theme (Ashdrift Hill / Everlight Grove). Per-theme counts are uneven (4–6).

## Paths

- JSON: `app_codebase/python_base_05/bin/modules/catalog/data/series/civilizations/`
- Art: `assets/images/arcori/004_civilizations/{theme}/`
- Public URL: `/catalog-media/004_civilizations/{theme}/{art_basename}.webp`
- Import tool: `import_civilizations_series.py` (default = item append; `--bootstrap` = original 60)
- Source folders archived under `assets/images/arcori/additions/_imported_civilizations/`

## Notes

- JSON `internalId` includes `GEN001`; art filenames omit GEN (`art_basename`).
- Starter pool stays Genesis + Pioneers only.
- Runtime catalog SSOT is Postgres — run `wfrun automation/backend/import_catalog_designs.py` (or `--apply`) to seed the new ids.

## Case study

Recorded Civilizations series + “region is a land, never Velora” + near-dup drop rule in `03_CASE_STUDY.md`.

## Task Manager

App Dev checklist: Civilizations series import (`SER004`); item batch 34 after near-dup drop.
