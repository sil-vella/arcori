# Pioneers Catalog Expansion (Nostalgia / Music / Television)

**Status**: Completed  
**Created**: 2026-08-27  
**Last Updated**: 2026-08-27

## Objective

Import 75 new Arcori designs from `assets/game_data` into the catalog using the existing design JSON shape, with matching 1:1 webp art.

## Implementation Steps
- [x] Review source sets and existing Pioneers categories
- [x] Create Nostalgia, Music, and Television theme folders (nothing existing fit those collections)
- [x] Convert PNG art to `{internalId}.webp` at 1254×1254
- [x] Write `nostalgia.json`, `music.json`, `television.json` in the catalog design schema
- [x] Register new themes in `00_themes_subthemes.json`
- [x] Reassign Realm Beyond designs to Velora lands
- [x] Move the 75 new designs into Genesis (`GEN001`, legacy 500/1000); keep original 10 in Pioneers

## Current Progress

75 designs live in Genesis (`NOS`/`MUS`/`TEL`, `GEN001-0001` … per theme). Pioneers still has only the original 10 seed designs (`GEN002-0001` … `0010`, legacy 100/200).

## Next Steps

None for this import. Velora picks up new themes from catalog meta on the next data read.

## Files Modified
- `assets/images/arcori/genesis/nostalgia/` (35 webp)
- `assets/images/arcori/genesis/music/` (20 webp)
- `assets/images/arcori/genesis/television/` (20 webp)
- `app_codebase/python_base_05/bin/modules/catalog/data/series/genesis/nostalgia.json`
- `app_codebase/python_base_05/bin/modules/catalog/data/series/genesis/music.json`
- `app_codebase/python_base_05/bin/modules/catalog/data/series/genesis/television.json`
- `app_codebase/python_base_05/bin/modules/catalog/data/00_themes_subthemes.json`
- `Documentation/01_Active_Plans/00_MASTER_PLAN.md`

## Notes

Existing Pioneers themes (animals, gaming, history, …) did not cover 1990s objects, music, or TV, so three new theme codes were added: `NOS`, `MUS`, `TEL`. Catalog loader already scans `series/**/*.json`; no loader change.

11 designs that had been given Realm Beyond (`RBY`) were moved onto Velora lands: Moonwake Bay, Amberwild, Ashdrift Hill, Everlight Grove, or Little Frost. Affinity/hostility follow those regions. Two lore lines that named the Realm Beyond were rewritten.

The 75 new designs were then moved from Pioneers to Genesis so they share Genesis legacy (`preservationRequirement` 500, `closureMilestone` 1000) and `GEN001` ids. Pioneers remains the original 10-theme seed **because** its lower legacy (100 / 200) is the reason the series exists — those ten can mint earlier than Genesis. Recorded in Game_Specific GDD, Content Bible, World Bible, and Tech Spec.

## Case study

Case study: Game_Specific (GDD / Content Bible / World Bible / Tech Spec) + [03_CASE_STUDY.md](03_CASE_STUDY.md) §18 — Pioneers exists for earlier mint (legacy 100/200).

## Task Manager

App Dev (`32`) checklist `155` — catalog expansion (done). Ideas (`18`) untouched.
